require "test_helper"

class ReviewFixesTest < ActiveSupport::TestCase
  test "token issuing rechecks membership under a lock on the user" do
    stale = User.find(users(:dave).id)
    User.find(users(:dave).id).update!(groups: [ "trivista-users" ])

    assert_raises(ActiveRecord::RecordNotFound) do
      UploadToken.issue_for!(user: stale, service_account: service_accounts(:shop_ci), expires_at: 1.day.from_now)
    end
  end

  test "token issuing refuses users deactivated in the meantime" do
    stale = User.find(users(:dave).id)
    User.find(users(:dave).id).deactivate!

    assert_raises(ActiveRecord::RecordNotFound) do
      UploadToken.issue_for!(user: stale, service_account: service_accounts(:shop_ci), expires_at: 1.day.from_now)
    end
  end

  test "the default branch rule does not override a manual choice made in the meantime" do
    repo = repos(:shop_backend)
    develop = repo.branches.create!(name: "develop")
    stale = Repo.find(repo.id)
    Repo.find(repo.id).update!(default_branch: develop, default_branch_manual: true)

    stale.apply_default_branch_rule!

    assert_equal develop, repo.reload.default_branch
  end

  test "long text fields are truncated" do
    report = TrivyReport.parse(report_with(vulnerability("Description" => "x" * 20_000, "Title" => "t" * 5_000,
      "References" => Array.new(80) { "https://ref.example.com/#{it}" })).to_json)
    attributes = report.findings.sole.attributes

    assert_equal 10_000, attributes[:description].length
    assert attributes[:description].end_with?("…")
    assert_equal 1_000, attributes[:title].length
    assert_equal 50, attributes[:references].size
  end

  test "reports with too many findings are rejected" do
    Rails.configuration.x.max_findings_per_report = 2
    vulnerabilities = Array.new(3) { vulnerability("VulnerabilityID" => "CVE-#{it}") }

    assert_raises(TrivyReport::UnsupportedReport) { TrivyReport.parse(report_with(*vulnerabilities).to_json) }
  ensure
    Rails.configuration.x.max_findings_per_report = 50_000
  end

  test "the quota is checked before anything is imported" do
    report = TrivyReport.parse(report_with(vulnerability).to_json)
    upload = Upload.new(service_account: service_accounts(:shop_ci), project: "shop", repo: "backend", branch: "main",
      commit: "abc", report:, occurrence_quota: owners(:team_a).occurrence_count)

    assert_no_difference [ "Scan.count", "Finding.count", "Occurrence.count" ] do
      assert_raises(Upload::QuotaExceeded) { upload.import }
    end
  end

  test "scan rows are aggregated and limited in the database" do
    scan = scans(:shop_main_first)
    3.times do |index|
      finding = projects(:shop).findings.create!(finding_type: "vulnerability", identifier: "CVE-9#{index}",
        fingerprint: "limit-#{index}")
      scan.occurrences.create!(finding:, severity: "CRITICAL", installed_version: "1")
    end

    page = ScanFindings.new(scan).page(limit: 2)

    assert_equal 4, page.total
    assert_equal [ "CVE-90", "CVE-91" ], page.rows.map { it.finding.identifier }
  end

  private
    def report_with(*vulnerabilities)
      { "SchemaVersion" => 2, "ArtifactName" => ".", "ArtifactType" => "filesystem",
        "Results" => [ { "Target" => "Gemfile.lock", "Class" => "lang-pkgs", "Type" => "bundler", "Vulnerabilities" => vulnerabilities } ] }
    end

    def vulnerability(overrides = {})
      { "VulnerabilityID" => "CVE-2024-0001", "PkgName" => "pkg", "Severity" => "HIGH" }.merge(overrides)
    end
end
