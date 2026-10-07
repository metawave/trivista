# Writes a parsed Trivy report as one scan of a branch, in a single transaction (ADR 0002, ADR 0004).
class ScanImporter
  FINDING_COLUMNS = %i[identifier namespace misconfiguration_type pkg_name target resource provider service category
    title description resolution primary_url references published_at last_modified_at].freeze
  OCCURRENCE_COLUMNS = %i[installed_version location fixed_version status severity start_line end_line confidence].freeze
  BATCH_SIZE = 1000

  def initialize(branch:, service_account:, commit_sha:, tag: nil, trigger: "unknown")
    @branch = branch
    @service_account = service_account
    @commit_sha = commit_sha
    @tag = tag
    @trigger = trigger
  end

  def import(report)
    Scan.transaction do
      scan = create_scan(report)
      finding_ids = upsert_findings(report.findings)
      insert_occurrences(scan, report.findings, finding_ids)
      scan
    end
  end

  private
    attr_reader :branch, :service_account, :commit_sha, :tag, :trigger

    def project
      branch.repo.project
    end

    def create_scan(report)
      artifact = project.artifacts.create_or_find_by!(category: report.artifact_category, name: report.artifact_name)

      Scan.create!(branch:, artifact:, service_account:, commit_sha:, tag:, trigger:,
        reported_artifact_type: report.reported_artifact_type, reported_artifact_name: report.reported_artifact_name,
        schema_version: report.schema_version, report_created_at: report.report_created_at,
        trivy_version: report.trivy_version, os_family: report.os_family, os_name: report.os_name,
        counts: counts(report.findings))
    end

    def upsert_findings(findings)
      return {} if findings.empty?

      rows = findings.uniq(&:fingerprint).map do |finding|
        FINDING_COLUMNS.index_with { nil }.merge(references: []).merge(finding.attributes)
          .merge(project_id: project.id, finding_type: finding.finding_type, fingerprint: finding.fingerprint)
      end
      rows.each_slice(BATCH_SIZE).each_with_object({}) do |batch, ids|
        Finding.upsert_all(batch, unique_by: %i[project_id fingerprint], returning: %i[id fingerprint])
          .each { ids[it["fingerprint"]] = it["id"] }
      end
    end

    def insert_occurrences(scan, findings, finding_ids)
      rows = findings
        .group_by(&:occurrence_key)
        .map { |_, same| most_severe(same) }
        .map do |finding|
          OCCURRENCE_COLUMNS.index_with { nil }.merge(finding.observation)
            .merge(scan_id: scan.id, finding_id: finding_ids.fetch(finding.fingerprint))
        end
      rows.each_slice(BATCH_SIZE) { Occurrence.insert_all!(it) }
    end

    def counts(findings)
      findings.group_by(&:fingerprint).values.map { most_severe(it) }
        .group_by(&:finding_type)
        .transform_values { |same_type| same_type.map { it.observation[:severity] }.tally }
    end

    def most_severe(findings)
      findings.min_by { Occurrence::SEVERITIES.index(it.observation[:severity]) }
    end
end
