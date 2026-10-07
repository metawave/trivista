# Translates a Trivy JSON report into Trivista domain values. Reads only allowlisted fields (ADR 0003).
class TrivyReport
  class InvalidReport < StandardError; end
  class UnsupportedReport < StandardError; end

  Finding = Data.define(:finding_type, :fingerprint, :attributes, :observation) do
    def occurrence_key
      [ fingerprint, observation[:installed_version], observation[:location] ]
    end
  end

  TEXT_LIMIT = 1_000
  LONG_TEXT_LIMIT = 10_000
  REFERENCE_LIMIT = 50

  ARTIFACT_CATEGORIES = {
    "container_image" => "container_image", "filesystem" => "source", "repository" => "source",
    "vm" => "vm", "cyclonedx" => "cyclonedx", "spdx" => "spdx", "aws_account" => "aws_account"
  }.freeze
  URL = %r{\A([a-z][a-z0-9+.\-]*://)(?:[^/?#]*@)?([^/?#]*)([^?#]*)}i
  BUILTIN_CHECK_ID = /\A([A-Z]+)-?0*(\d+)\z/

  attr_reader :artifact_category, :artifact_name, :reported_artifact_type, :reported_artifact_name,
    :schema_version, :report_created_at, :trivy_version, :os_family, :os_name, :findings

  def self.parse(json)
    new(JSON.parse(json))
  rescue JSON::ParserError
    raise InvalidReport, "Trivy report is not valid JSON"
  end

  def initialize(document)
    raise InvalidReport, "Trivy report must be a JSON object" unless document.is_a?(Hash)
    raise UnsupportedReport, "trivy k8s reports are not supported" if document.key?("ClusterName")
    raise UnsupportedReport, "only Trivy reports with SchemaVersion 2 are supported" unless document["SchemaVersion"] == 2

    read_metadata(document)
    results = list(document["Results"])
    reject_oversized(results)
    @findings = results.flat_map { findings_of(it) }
  end

  def occurrence_count
    findings.map(&:occurrence_key).uniq.size
  end

  private
    # Bounds memory before findings are projected; many tiny entries fit into a small upload (ADR 0004).
    def reject_oversized(results)
      count = results.sum { |result| %w[Vulnerabilities Misconfigurations Secrets Licenses].sum { list(result[it]).size } }
      return if count <= Rails.configuration.x.max_findings_per_report

      raise UnsupportedReport, "report has more than #{Rails.configuration.x.max_findings_per_report} findings"
    end

    def read_metadata(document)
      @schema_version = document["SchemaVersion"]
      @reported_artifact_type = string(document["ArtifactType"])
      @artifact_category = ARTIFACT_CATEGORIES.fetch(reported_artifact_type) { raise UnsupportedReport, "unsupported ArtifactType" }
      @reported_artifact_name = sanitize_url(string(document["ArtifactName"]) || raise(InvalidReport, "ArtifactName is missing"))
      @artifact_name = image? ? strip_image_tag(reported_artifact_name) : reported_artifact_name
      @report_created_at = time(document["CreatedAt"])
      @trivy_version = string(object(document["Trivy"])["Version"])
      os = object(object(document["Metadata"])["OS"])
      @os_family = string(os["Family"])
      @os_name = string(os["Name"])
    end

    def findings_of(result)
      context = { target: normalize_target(string(result["Target"])), result_class: string(result["Class"]), result_type: string(result["Type"]) }

      list(result["Vulnerabilities"]).map { vulnerability(it, **context) } +
        list(result["Misconfigurations"]).select { it["Status"] == "FAIL" }.map { misconfiguration(it, **context) } +
        list(result["Secrets"]).map { secret(it, **context) } +
        list(result["Licenses"]).map { license(it, **context) }
    end

    def vulnerability(entry, target:, result_class:, result_type:)
      identifier = required_string(entry["VulnerabilityID"])
      pkg_name = string(entry["PkgName"])
      location_key = result_class == "os-pkgs" ? "os-pkgs:#{result_type}" : target

      build("vulnerability", [ identifier, pkg_name, location_key ],
        attributes: { identifier:, pkg_name:, target:, title: string(entry["Title"]), description: string(entry["Description"], limit: LONG_TEXT_LIMIT),
          primary_url: sanitized_string(entry["PrimaryURL"]), references: sanitized_list(entry["References"]),
          published_at: time(entry["PublishedDate"]), last_modified_at: time(entry["LastModifiedDate"]) },
        observation: { installed_version: string(entry["InstalledVersion"]), location: string(entry["PkgPath"]),
          fixed_version: string(entry["FixedVersion"]), status: string(entry["Status"]), severity: severity(entry) })
    end

    def misconfiguration(entry, target:, **)
      namespace = string(entry["Namespace"])
      builtin = namespace.to_s.start_with?("builtin.")
      raw_identifier = required_string(entry["ID"])
      identifier = builtin ? normalize_builtin_id(raw_identifier) : raw_identifier
      cause = object(entry["CauseMetadata"])
      resource = string(cause["Resource"])
      start_line = integer(cause["StartLine"])
      position = resource || ("line:#{start_line}" if start_line)

      build("misconfiguration", [ identifier, builtin ? "builtin" : namespace, target, position ],
        attributes: { identifier:, namespace:, misconfiguration_type: string(entry["Type"]), target:, resource:,
          provider: string(cause["Provider"]), service: string(cause["Service"]), title: string(entry["Title"]),
          description: string(entry["Description"], limit: LONG_TEXT_LIMIT),
          resolution: string(entry["Resolution"], limit: LONG_TEXT_LIMIT),
          primary_url: sanitized_string(entry["PrimaryURL"]), references: sanitized_list(entry["References"]) },
        observation: { severity: severity(entry), start_line:, end_line: integer(cause["EndLine"]) })
    end

    def secret(entry, target:, **)
      identifier = required_string(entry["RuleID"])
      start_line = integer(entry["StartLine"])

      build("secret", [ identifier, target, start_line ],
        attributes: { identifier:, target:, category: string(entry["Category"]), title: string(entry["Title"]) },
        observation: { severity: severity(entry), start_line:, end_line: integer(entry["EndLine"]) })
    end

    def license(entry, target:, **)
      identifier = required_string(entry["Name"])
      pkg_name = string(entry["PkgName"])
      file_path = string(entry["FilePath"])

      build("license", [ identifier, target, pkg_name || file_path ],
        attributes: { identifier:, pkg_name:, target:, category: string(entry["Category"]),
          primary_url: sanitized_string(entry["Link"]) },
        observation: { severity: severity(entry), location: file_path, confidence: number(entry["Confidence"]) })
    end

    def build(finding_type, identity, attributes:, observation:)
      Finding.new(finding_type:, fingerprint: Digest::SHA256.hexdigest(JSON.generate([ finding_type, *identity ])),
        attributes:, observation:)
    end

    def image?
      artifact_category == "container_image"
    end

    def strip_image_tag(name)
      name = name.split("@", 2).first
      tag_separator = name.rindex(":")
      return name unless tag_separator && tag_separator > name.rindex("/").to_i

      name[0...tag_separator]
    end

    def normalize_target(target)
      return target unless image? && target&.start_with?(reported_artifact_name)

      artifact_name + target.delete_prefix(reported_artifact_name)
    end

    def normalize_builtin_id(identifier)
      identifier = identifier.delete_prefix("AVD-")
      match = BUILTIN_CHECK_ID.match(identifier)
      match ? format("%s-%04d", match[1], match[2].to_i) : identifier
    end

    def sanitize_url(value)
      match = URL.match(value)
      match ? match.captures.join : value
    end

    def sanitized_string(value)
      string(value)&.then { sanitize_url(it) }
    end

    def sanitized_list(value)
      return [] if value.nil?
      raise InvalidReport, "unexpected Trivy report structure" unless value.is_a?(Array)

      value.first(REFERENCE_LIMIT).filter_map { sanitized_string(it) }
    end

    def severity(entry)
      value = string(entry["Severity"])
      Occurrence::SEVERITIES.include?(value) ? value : "UNKNOWN"
    end

    def list(value)
      return [] if value.nil?
      raise InvalidReport, "unexpected Trivy report structure" unless value.is_a?(Array) && value.all?(Hash)

      value
    end

    def object(value)
      return {} if value.nil?
      raise InvalidReport, "unexpected Trivy report structure" unless value.is_a?(Hash)

      value
    end

    # Long values are cut, so a single finding cannot bypass the occurrence quota with huge texts.
    def string(value, limit: TEXT_LIMIT)
      return if value.nil? || value == ""
      raise InvalidReport, "unexpected Trivy report structure" unless value.is_a?(String)

      value.truncate(limit, omission: "…")
    end

    def required_string(value)
      string(value) || raise(InvalidReport, "unexpected Trivy report structure")
    end

    def integer(value)
      return if value.nil?
      raise InvalidReport, "unexpected Trivy report structure" unless value.is_a?(Integer)

      value
    end

    def number(value)
      return if value.nil?
      raise InvalidReport, "unexpected Trivy report structure" unless value.is_a?(Numeric)

      value
    end

    def time(value)
      string(value)&.then { Time.iso8601(it) }
    rescue ArgumentError
      raise InvalidReport, "unexpected Trivy report structure"
    end
end
