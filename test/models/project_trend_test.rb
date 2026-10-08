require "test_helper"

class ProjectTrendTest < ActiveSupport::TestCase
  setup do
    @project = projects(:shop)
    @main = branches(:shop_backend_main)
    repos(:shop_backend).update!(default_branch: @main)
    @image = artifacts(:shop_image)
    @source = @project.artifacts.create!(category: "source", name: ".")
    scans(:shop_main_first).destroy!
  end

  test "sums the latest scan of every artifact per day and carries it forward" do
    scan(@main, @image, { "HIGH" => 2 }, 3.days.ago)
    scan(@main, @source, { "HIGH" => 1, "LOW" => 4 }, 2.days.ago)
    scan(@main, @image, { "HIGH" => 5 }, 1.day.ago)

    points = ProjectTrend.new(@project, finding_type: "vulnerability", since: 3.days.ago).points

    assert_equal 4, points.size
    assert_equal [ { "HIGH" => 2 }, { "HIGH" => 3, "LOW" => 4 }, { "HIGH" => 6, "LOW" => 4 }, { "HIGH" => 6, "LOW" => 4 } ],
      points.map(&:counts)
  end

  test "drops artifacts without a scan in the activity window and ignores other branches" do
    feature = repos(:shop_backend).branches.create!(name: "feature")
    scan(@main, @image, { "HIGH" => 2 }, 32.days.ago)
    scan(feature, @image, { "CRITICAL" => 9 }, 1.day.ago)

    points = ProjectTrend.new(@project, finding_type: "vulnerability", since: 2.days.ago).points

    assert_equal [ {}, {}, {} ], points.map(&:counts)
  end

  test "without a range it starts at the first scan" do
    scan(@main, @image, { "HIGH" => 1 }, 2.days.ago)

    assert_equal 3, ProjectTrend.new(@project, finding_type: "vulnerability").points.size
  end

  private
    def scan(branch, artifact, severities, at)
      Scan.create!(branch:, artifact:, service_account: service_accounts(:shop_ci), commit_sha: "c0ffee",
        reported_artifact_type: "container_image", reported_artifact_name: artifact.name,
        counts: { "vulnerability" => severities }, created_at: at)
    end
end
