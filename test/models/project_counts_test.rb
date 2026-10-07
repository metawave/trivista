require "test_helper"

class ProjectCountsTest < ActiveSupport::TestCase
  setup do
    @repo = repos(:shop_backend)
    @main = branches(:shop_backend_main)
    @repo.update!(default_branch: @main)
    @image = artifacts(:shop_image)
    @source = projects(:shop).artifacts.create!(category: "source", name: ".")
    scans(:shop_main_first).update!(created_at: 40.days.ago)
  end

  test "sums the latest scan of each artifact on the default branches" do
    scan(@main, @image, { "vulnerability" => { "HIGH" => 9 } }, 2.days.ago)
    scan(@main, @image, { "vulnerability" => { "HIGH" => 2, "LOW" => 1 } }, 1.day.ago)
    scan(@main, @source, { "vulnerability" => { "HIGH" => 1 }, "secret" => { "CRITICAL" => 1 } }, 1.day.ago)

    assert_equal({ "vulnerability" => { "HIGH" => 3, "LOW" => 1 }, "secret" => { "CRITICAL" => 1 } },
      Project.current_counts(Project.where(id: projects(:shop))).fetch(projects(:shop).id))
  end

  test "ignores branches other than the default branch" do
    feature = @repo.branches.create!(name: "feature")
    scan(feature, @image, { "vulnerability" => { "CRITICAL" => 5 } }, 1.hour.ago)

    assert_equal({}, Project.current_counts(Project.where(id: projects(:shop))).fetch(projects(:shop).id, {}))
  end

  test "ignores artifacts without a scan in the activity window" do
    scan(@main, @image, { "vulnerability" => { "HIGH" => 1 } }, 1.day.ago)
    scan(@main, @source, { "vulnerability" => { "HIGH" => 7 } }, 31.days.ago)

    assert_equal({ "vulnerability" => { "HIGH" => 1 } },
      Project.current_counts(Project.where(id: projects(:shop))).fetch(projects(:shop).id))
  end

  private
    def scan(branch, artifact, counts, at)
      Scan.create!(branch:, artifact:, service_account: service_accounts(:shop_ci), commit_sha: "c0ffee",
        reported_artifact_type: "container_image", reported_artifact_name: artifact.name, counts:, created_at: at)
    end
end
