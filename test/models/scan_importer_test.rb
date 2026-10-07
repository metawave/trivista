require "test_helper"

class ScanImporterTest < ActiveSupport::TestCase
  LEAK = "TRIVISTA-LEAK-MARKER"

  setup do
    @branch = branches(:shop_backend_main)
    @project = projects(:shop)
  end

  test "imports a filesystem scan with scan metadata" do
    scan = import(fixture_report("fs"))

    assert_equal "source", scan.artifact.category
    assert_equal ".", scan.artifact.name
    assert_equal "filesystem", scan.reported_artifact_type
    assert_equal "0.75.0", scan.trivy_version
    assert_equal "abc123", scan.commit_sha
    assert_equal service_accounts(:shop_ci), scan.service_account
  end

  test "several versions of one package are occurrences of a single finding counted once" do
    scan = import(fixture_report("fs"))
    lodash = scan.occurrences.joins(:finding).where(findings: { pkg_name: "lodash" })

    assert_equal [ "4.17.15", "4.17.20" ], lodash.distinct.pluck(:installed_version).sort
    assert_operator lodash.count, :>, lodash.distinct.count(:finding_id)
    assert_equal scan.occurrences.distinct.count(:finding_id), scan.counts.values.sum { it.values.sum }
  end

  test "counts use the highest severity per finding" do
    report = report_with_vulnerabilities(
      { "InstalledVersion" => "1.0.0", "Severity" => "LOW" },
      { "InstalledVersion" => "2.0.0", "Severity" => "CRITICAL" }
    )

    scan = import(report)

    assert_equal({ "vulnerability" => { "CRITICAL" => 1 } }, scan.counts)
  end

  test "importing the same report again creates no new findings" do
    import(fixture_report("fs"))

    assert_no_difference -> { Finding.count } do
      assert_difference -> { Scan.count } do
        import(fixture_report("fs"))
      end
    end
  end

  test "an upgrade without fix keeps the finding" do
    first = import(report_with_vulnerabilities({ "InstalledVersion" => "1.0.0" }))
    second = import(report_with_vulnerabilities({ "InstalledVersion" => "1.0.1" }))

    assert_equal first.occurrences.pluck(:finding_id), second.occurrences.pluck(:finding_id)
  end

  test "a new image tag reuses artifact and os package findings" do
    first = import(fixture_report("image"))
    retagged = retag_image(fixture_report("image"), "trivista-fixture:1.0.0", "trivista-fixture:2.0.0")

    second = import(retagged)

    assert_equal first.artifact, second.artifact
    assert_equal first.occurrences.pluck(:finding_id).sort, second.occurrences.pluck(:finding_id).sort
  end

  test "a clean report creates a scan without findings" do
    scan = import(fixture_report("fs").except("Results"))

    assert_empty scan.occurrences
    assert_equal({}, scan.counts)
  end

  test "a failing import leaves nothing behind" do
    report = fixture_report("fs")

    assert_no_difference [ "Scan.count", "Finding.count", "Occurrence.count", "Artifact.count" ] do
      assert_raises(ActiveRecord::RecordInvalid) { import(report, trigger: "nightly") }
    end
  end

  test "no secret from the report ends up in the database" do
    import(plant_leaks(fixture_report("fs")))
    import(plant_leaks(fixture_report("image")))
    import(plant_leaks(fixture_report("fs").merge("ArtifactType" => "repository",
      "ArtifactName" => "https://user:#{LEAK}@git.example.com/org/repo.git?token=#{LEAK}#{LEAK}")))

    assert_no_match(/#{LEAK}/o, database_dump)
    assert_no_match(/FakeImageEnvSecret|context-line-password|ghp_FAKE/, database_dump)
  end

  private
    def import(report, trigger: "push")
      ScanImporter.new(branch: @branch, service_account: service_accounts(:shop_ci),
        commit_sha: "abc123", trigger: trigger).import(TrivyReport.parse(report.to_json))
    end

    def fixture_report(name)
      JSON.parse(file_fixture("trivy/#{name}.json").read)
    end

    def report_with_vulnerabilities(*overrides)
      vulnerabilities = overrides.map do |override|
        { "VulnerabilityID" => "CVE-2024-0001", "PkgName" => "pkg", "Severity" => "HIGH", "Title" => "flaw" }.merge(override)
      end
      { "SchemaVersion" => 2, "ArtifactName" => ".", "ArtifactType" => "filesystem",
        "Results" => [ { "Target" => "Gemfile.lock", "Class" => "lang-pkgs", "Type" => "bundler", "Vulnerabilities" => vulnerabilities } ] }
    end

    def retag_image(report, from, to)
      JSON.parse(report.to_json.gsub(from, to))
    end

    def plant_leaks(report)
      report["Unknown"] = LEAK
      report["Metadata"] = (report["Metadata"] || {}).merge("ImageConfig" => { "config" => { "Env" => [ "KEY=#{LEAK}" ] } },
        "Layers" => [ { "CreatedBy" => "RUN #{LEAK}" } ], "RepoURL" => "https://x:#{LEAK}@host/repo")
      Array(report["Results"]).each do |result|
        result["Unknown"] = LEAK
        Array(result["Vulnerabilities"]).each do |vulnerability|
          vulnerability.merge!("Layer" => { "CreatedBy" => LEAK }, "NewField" => LEAK,
            "PrimaryURL" => "https://u:#{LEAK}@avd.example.com/x?t=#{LEAK}#{LEAK}", "References" => [ "https://r.example.com/?#{LEAK}" ])
        end
        Array(result["Misconfigurations"]).each do |misconfiguration|
          misconfiguration.merge!("Message" => LEAK, "Traces" => [ LEAK ], "RenderedCause" => { "Raw" => LEAK })
          misconfiguration["CauseMetadata"] = (misconfiguration["CauseMetadata"] || {}).merge("Code" => { "Lines" => [ { "Content" => LEAK } ] })
        end
        Array(result["Secrets"]).each do |secret|
          secret.merge!("Match" => LEAK, "Code" => { "Lines" => [ { "Content" => LEAK, "Highlighted" => LEAK } ] })
        end
        Array(result["Licenses"]).each { it.merge!("Text" => LEAK, "Link" => "https://l.example.com/?k=#{LEAK}") }
        result["ExperimentalModifiedFindings"] = [ { "Type" => "secret", "Finding" => { "Match" => LEAK } } ]
      end
      report
    end

    def database_dump
      connection = ActiveRecord::Base.connection
      connection.tables.map { |table|
        connection.select_values("SELECT row_to_json(t)::text FROM #{connection.quote_table_name(table)} t").join("\n")
      }.join("\n")
    end
end
