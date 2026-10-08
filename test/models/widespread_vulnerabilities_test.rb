require "test_helper"

class WidespreadVulnerabilitiesTest < ActiveSupport::TestCase
  setup do
    @shop_branch = branches(:shop_backend_main)
    repos(:shop_backend).update!(default_branch: @shop_branch)
    @tools_branch = branches(:alice_tools_cli_main)
    repos(:alice_tools_cli).update!(default_branch: @tools_branch)
    scans(:shop_main_first).update!(created_at: 1.day.ago)
    scans(:alice_tools_first).update!(created_at: 1.day.ago)
  end

  test "ranks vulnerabilities by the number of projects they currently occur in" do
    occur(scans(:shop_main_first), :shop, "CVE-2024-0001", "LOW")
    occur(scans(:alice_tools_first), :alice_tools, "CVE-2024-0001", "HIGH")
    occur(scans(:shop_main_first), :shop, "CVE-2024-0002", "CRITICAL")
    occur(scans(:shop_main_first), :shop, "aws-access-key-id", "CRITICAL", finding_type: "secret")

    rows = WidespreadVulnerabilities.new(Project.where(id: [ projects(:shop).id, projects(:alice_tools).id ])).top(limit: 2)

    assert_equal [ "CVE-2024-0001", "CVE-2024-0002" ], rows.map(&:identifier)
    assert_equal [ 2, 1 ], rows.map(&:project_count)
    assert_equal "HIGH", rows.first.severity
  end

  test "counts only the current scans of the default branches" do
    feature = repos(:alice_tools_cli).branches.create!(name: "feature")
    feature_scan = Scan.create!(branch: feature, artifact: scans(:alice_tools_first).artifact, service_account: service_accounts(:alice_ci),
      commit_sha: "f", reported_artifact_type: "filesystem", reported_artifact_name: ".")
    occur(feature_scan, :alice_tools, "CVE-2024-0001", "HIGH")
    occur(scans(:shop_main_first), :shop, "CVE-2024-0001", "HIGH")

    rows = WidespreadVulnerabilities.new(Project.all).top(limit: 5)

    assert_equal 1, rows.find { it.identifier == "CVE-2024-0001" }.project_count
  end

  private
    def occur(scan, project, identifier, severity, finding_type: "vulnerability")
      finding = projects(project).findings.create!(finding_type:, identifier:, pkg_name: "openssl",
        fingerprint: Digest::SHA256.hexdigest("#{project}#{identifier}"))
      scan.occurrences.create!(finding:, severity:)
    end
end
