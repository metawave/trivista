require "test_helper"

class TrivyReportTest < ActiveSupport::TestCase
  test "reads report metadata from a filesystem scan" do
    report = TrivyReport.parse(file_fixture("trivy/fs.json").read)

    assert_equal "source", report.artifact_category
    assert_equal ".", report.artifact_name
    assert_equal "filesystem", report.reported_artifact_type
    assert_equal 2, report.schema_version
    assert_equal "0.75.0", report.trivy_version
  end

  test "reads os metadata from an image scan" do
    report = TrivyReport.parse(file_fixture("trivy/image.json").read)

    assert_equal "container_image", report.artifact_category
    assert_equal "trivista-fixture", report.artifact_name
    assert_equal "trivista-fixture:1.0.0", report.reported_artifact_name
    assert_equal "alpine", report.os_family
    assert_equal "3.18.0", report.os_name
  end

  test "rejects invalid json without echoing its content" do
    error = assert_raises(TrivyReport::InvalidReport) { TrivyReport.parse('{"SchemaVersion": 2, "secret-value') }

    assert_no_match(/secret-value/, error.message)
  end

  test "rejects valid json with an unexpected structure" do
    assert_raises(TrivyReport::InvalidReport) { TrivyReport.parse("[1, 2]") }
    assert_raises(TrivyReport::InvalidReport) { TrivyReport.parse(build_report("Results" => "nope").to_json) }
  end

  test "rejects kubernetes reports and other schema versions" do
    assert_raises(TrivyReport::UnsupportedReport) { TrivyReport.parse({ "ClusterName" => "prod", "Resources" => [] }.to_json) }
    assert_raises(TrivyReport::UnsupportedReport) { TrivyReport.parse(build_report("SchemaVersion" => 1).to_json) }
  end

  test "rejects unknown artifact types" do
    assert_raises(TrivyReport::UnsupportedReport) { TrivyReport.parse(build_report("ArtifactType" => "spaceship").to_json) }
  end

  test "missing results is a clean report" do
    report = TrivyReport.parse(build_report.except("Results").to_json)

    assert_empty report.findings
  end

  test "filesystem and repository share the source category" do
    assert_equal "source", parse(build_report("ArtifactType" => "repository")).artifact_category
    assert_equal "source", parse(build_report("ArtifactType" => "filesystem")).artifact_category
  end

  test "image names lose tag and digest but keep registry ports" do
    {
      "app:1.2" => "app",
      "app@sha256:abc" => "app",
      "app:1.2@sha256:abc" => "app",
      "registry.example.com:5000/team/app:1.2" => "registry.example.com:5000/team/app",
      "localhost:5000/app" => "localhost:5000/app",
      "[::1]:5000/app:1.2" => "[::1]:5000/app",
      "app" => "app"
    }.each do |raw, expected|
      report = parse(build_report("ArtifactType" => "container_image", "ArtifactName" => raw))

      assert_equal expected, report.artifact_name, raw
    end
  end

  test "urls keep only scheme, host and path" do
    report = parse(build_report(
      "ArtifactType" => "repository",
      "ArtifactName" => "https://user:pass@git.example.com:8443/org/repo.git?token=abc#frag",
      "Results" => [ { "Target" => "package-lock.json", "Class" => "lang-pkgs", "Type" => "npm",
        "Vulnerabilities" => [ vulnerability("PrimaryURL" => "https://a:b@avd.example.com/CVE-1?access_token=x",
          "References" => [ "https://ref.example.com/x?y=z#w", "not a url" ]) ] } ]
    ))
    finding = report.findings.sole

    assert_equal "https://git.example.com:8443/org/repo.git", report.artifact_name
    assert_equal "https://avd.example.com/CVE-1", finding.attributes[:primary_url]
    assert_equal [ "https://ref.example.com/x", "not a url" ], finding.attributes[:references]
  end

  test "vulnerability fingerprint ignores installed version and package path" do
    first = vulnerability_finding("InstalledVersion" => "1.0.0", "PkgPath" => "lib/a-1.0.0.jar")
    upgraded = vulnerability_finding("InstalledVersion" => "1.0.1", "PkgPath" => "lib/a-1.0.1.jar")

    assert_equal first.fingerprint, upgraded.fingerprint
    assert_equal "1.0.1", upgraded.observation[:installed_version]
    assert_equal "lib/a-1.0.1.jar", upgraded.observation[:location]
  end

  test "os package fingerprint does not depend on image tag or os version" do
    tagged = ->(tag, os) {
      parse(build_report("ArtifactType" => "container_image", "ArtifactName" => "app:#{tag}",
        "Results" => [ { "Target" => "app:#{tag} (alpine #{os})", "Class" => "os-pkgs", "Type" => "alpine",
          "Vulnerabilities" => [ vulnerability ] } ])).findings.sole
    }

    assert_equal tagged.call("1", "3.18.0").fingerprint, tagged.call("2", "3.19.1").fingerprint
  end

  test "image config targets are normalized like the artifact" do
    secret_in = ->(tag) {
      parse(build_report("ArtifactType" => "container_image", "ArtifactName" => "app:#{tag}",
        "Results" => [ { "Target" => "app:#{tag}", "Class" => "secret",
          "Secrets" => [ { "RuleID" => "aws-secret-access-key", "Severity" => "CRITICAL", "Title" => "AWS", "StartLine" => 1, "EndLine" => 1 } ] } ])).findings.sole
    }

    assert_equal secret_in.call("1").fingerprint, secret_in.call("2").fingerprint
    assert_equal "app", secret_in.call("1").attributes[:target]
  end

  test "builtin misconfiguration ids are normalized" do
    {
      "DS005" => "DS-0005",
      "AVD-DS-0005" => "DS-0005",
      "KSV011" => "KSV-0011",
      "AWS-0090" => "AWS-0090"
    }.each do |raw, expected|
      finding = misconfiguration_finding("ID" => raw, "Namespace" => "builtin.dockerfile.DS005")

      assert_equal expected, finding.attributes[:identifier], raw
    end
  end

  test "old and new builtin ids share a fingerprint, custom checks keep their id and namespace" do
    old_id = misconfiguration_finding("ID" => "DS005", "Namespace" => "builtin.dockerfile.DS005")
    new_id = misconfiguration_finding("ID" => "DS-0005", "Namespace" => "builtin.dockerfile.DS-0005")
    custom = misconfiguration_finding("ID" => "DS005", "Namespace" => "user.custom")

    assert_equal old_id.fingerprint, new_id.fingerprint
    assert_not_equal old_id.fingerprint, custom.fingerprint
    assert_equal "DS005", custom.attributes[:identifier]
  end

  test "misconfiguration location falls back to start line without resource" do
    on_line = ->(line) { misconfiguration_finding("CauseMetadata" => { "StartLine" => line }) }
    with_resource = misconfiguration_finding("CauseMetadata" => { "Resource" => "aws_s3_bucket.logs", "StartLine" => 3 })

    assert_not_equal on_line.call(3).fingerprint, on_line.call(4).fingerprint
    assert_equal with_resource.fingerprint,
      misconfiguration_finding("CauseMetadata" => { "Resource" => "aws_s3_bucket.logs", "StartLine" => 9 }).fingerprint
  end

  test "only failed misconfigurations become findings" do
    report = TrivyReport.parse(file_fixture("trivy/fs.json").read)

    assert_equal 3, report.findings.count { it.finding_type == "misconfiguration" }
  end

  test "license occurrences are located by file path" do
    report = TrivyReport.parse(file_fixture("trivy/fs.json").read)
    license = report.findings.find { it.finding_type == "license" }

    assert_equal "GPL-3.0-only", license.attributes[:identifier]
    assert_equal "gpl-lib", license.attributes[:pkg_name]
    assert_predicate license.observation[:location], :present?
  end

  test "suppressed findings are ignored" do
    report = TrivyReport.parse(file_fixture("trivy/fs.json").read)

    assert_not report.findings.any? { it.attributes[:identifier] == "CVE-2021-23337" }
    assert_not report.findings.any? { it.attributes[:identifier] == "aws-access-key-id" }
  end

  private
    def parse(report)
      TrivyReport.parse(report.to_json)
    end

    def build_report(overrides = {})
      { "SchemaVersion" => 2, "ArtifactName" => ".", "ArtifactType" => "filesystem", "Results" => [] }.merge(overrides)
    end

    def vulnerability(overrides = {})
      { "VulnerabilityID" => "CVE-2024-0001", "PkgName" => "pkg", "InstalledVersion" => "1.0.0",
        "Severity" => "HIGH", "Title" => "flaw" }.merge(overrides)
    end

    def vulnerability_finding(overrides = {})
      parse(build_report("Results" => [ { "Target" => "pom.xml", "Class" => "lang-pkgs", "Type" => "pom",
        "Vulnerabilities" => [ vulnerability(overrides) ] } ])).findings.sole
    end

    def misconfiguration_finding(overrides = {})
      misconfiguration = { "ID" => "DS-0002", "Namespace" => "builtin.dockerfile.DS002", "Status" => "FAIL",
        "Severity" => "HIGH", "Title" => "root user", "CauseMetadata" => {} }.merge(overrides)
      parse(build_report("Results" => [ { "Target" => "Dockerfile", "Class" => "config", "Type" => "dockerfile",
        "Misconfigurations" => [ misconfiguration ] } ])).findings.sole
    end
end
