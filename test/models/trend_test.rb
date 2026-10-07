require "test_helper"

class TrendTest < ActiveSupport::TestCase
  setup do
    @branch = branches(:shop_backend_main)
    @image = artifacts(:shop_image)
    @source = projects(:shop).artifacts.create!(category: "source", name: ".")
    scans(:shop_main_first).update!(created_at: 200.days.ago)
  end

  test "builds one series per artifact in upload order" do
    first = scan(@image, { "vulnerability" => { "HIGH" => 2 } }, 3.days.ago)
    second = scan(@image, { "vulnerability" => { "HIGH" => 1, "LOW" => 4 } }, 1.day.ago)
    other = scan(@source, { "vulnerability" => { "CRITICAL" => 7 } }, 2.days.ago)

    series = Trend.new(@branch, finding_type: "vulnerability", since: 90.days.ago).series

    assert_equal [ @image, @source ].sort_by(&:name), series.map(&:artifact).sort_by(&:name)
    image_series = series.find { it.artifact == @image }
    assert_equal [ first.id, second.id ], image_series.points.map(&:scan_id)
    assert_equal({ "HIGH" => 1, "LOW" => 4 }, image_series.points.last.counts)
    assert_equal [ other.id ], series.find { it.artifact == @source }.points.map(&:scan_id)
  end

  test "selects the counts of one finding type" do
    scan(@image, { "vulnerability" => { "HIGH" => 2 }, "secret" => { "CRITICAL" => 1 } }, 1.day.ago)

    point = Trend.new(@branch, finding_type: "secret", since: 90.days.ago).series.sole.points.sole

    assert_equal({ "CRITICAL" => 1 }, point.counts)
  end

  test "filters by time range" do
    scan(@image, {}, 40.days.ago)
    recent = scan(@image, {}, 1.day.ago)

    series = Trend.new(@branch, finding_type: "vulnerability", since: 30.days.ago).series

    assert_equal [ recent.id ], series.sole.points.map(&:scan_id)
  end

  private
    def scan(artifact, counts, at, trigger: "push")
      Scan.create!(branch: @branch, artifact:, service_account: service_accounts(:shop_ci), commit_sha: "c0ffee",
        reported_artifact_type: "container_image", reported_artifact_name: artifact.name, counts:, created_at: at, trigger:)
    end
end
