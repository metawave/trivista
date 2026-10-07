require "test_helper"

class UploadTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @owner = Owner.create!(group_name: "quota-race")
    @service_account = ServiceAccount.create!(owner: @owner, name: "ci")
    @report = TrivyReport.parse({ "SchemaVersion" => 2, "ArtifactName" => ".", "ArtifactType" => "filesystem",
      "Results" => [ { "Target" => "Gemfile.lock", "Class" => "lang-pkgs", "Type" => "bundler",
        "Vulnerabilities" => [ { "VulnerabilityID" => "CVE-2024-0001", "PkgName" => "pkg", "Severity" => "HIGH" } ] } ] }.to_json)
  end

  teardown do
    Project.where(owner: @owner).destroy_all
    @service_account.delete
    @owner.delete
  end

  test "parallel uploads cannot exceed the quota together" do
    results = Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Upload.new(service_account: @service_account, project: "race", repo: "repo", branch: "main",
            commit: "abc", report: @report, occurrence_quota: 1).import
          :imported
        rescue Upload::QuotaExceeded
          :rejected
        end
      end
    end.map(&:value)

    assert_equal [ :imported, :rejected ], results.sort
    assert_equal 1, @owner.reload.occurrence_count
  end
end
