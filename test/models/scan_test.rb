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

  test "current scans are the latest per branch and artifact inside the activity window" do
    main = branches(:shop_backend_main)
    feature = repos(:shop_backend).branches.create!(name: "feature")
    source = projects(:shop).artifacts.create!(category: "source", name: ".")
    scans(:shop_main_first).update!(created_at: 3.days.ago)
    latest_image = scan(main, artifacts(:shop_image), 1.day.ago)
    stale_source = scan(main, source, 31.days.ago)
    feature_image = scan(feature, artifacts(:shop_image), 1.hour.ago)

    assert_equal [ latest_image ], Scan.current(main).to_a
    assert_equal [ latest_image, feature_image ].sort_by(&:id), Scan.current([ main, feature ]).sort_by(&:id)
    assert_not_includes Scan.current(main), stale_source
  end

  private
    def scan(branch, artifact, at)
      Scan.create!(branch:, artifact:, service_account: service_accounts(:shop_ci), commit_sha: "c0ffee",
        reported_artifact_type: "container_image", reported_artifact_name: artifact.name, created_at: at)
    end
end
