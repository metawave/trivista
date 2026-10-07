require "test_helper"

class ScanTest < ActiveSupport::TestCase
  test "trigger defaults to unknown" do
    scan = Scan.create!(branch: branches(:shop_backend_main), artifact: artifacts(:shop_image),
      service_account: service_accounts(:shop_ci), commit_sha: "abc123",
      reported_artifact_type: "container_image", reported_artifact_name: "registry.example.com/shop:2.0.0")

    assert_equal "unknown", scan.trigger
  end

  test "trigger is restricted to known values" do
    assert_raises(ActiveRecord::StatementInvalid) { scans(:shop_main_first).update_column(:trigger, "nightly") }
  end

  test "commit is required" do
    assert_raises(ActiveRecord::NotNullViolation) { scans(:shop_main_first).update_column(:commit_sha, nil) }
  end

  test "counts start empty" do
    assert_equal({}, scans(:shop_main_first).counts)
  end
end
