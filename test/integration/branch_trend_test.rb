require "test_helper"

class BranchTrendTest < ActionDispatch::IntegrationTest
  setup do
    scans(:shop_main_first).update!(counts: { "vulnerability" => { "HIGH" => 3 } }, created_at: 1.day.ago)
    sign_in(sub: "dave-sub")
  end

  test "renders one chart per artifact with its points" do
    get branch_path(branches(:shop_backend_main))

    assert_response :success
    assert_select "[data-controller=trend]", 1
    points = JSON.parse(css_select("[data-controller=trend]").first["data-trend-points-value"])
    assert_equal [ { "HIGH" => 3 } ], points.map { it["counts"] }
  end

  test "switches the finding type" do
    get branch_path(branches(:shop_backend_main), type: "secret")

    points = JSON.parse(css_select("[data-controller=trend]").first["data-trend-points-value"])
    assert_equal [ {} ], points.map { it["counts"] }
  end

  test "rejects unknown filter values" do
    get branch_path(branches(:shop_backend_main), type: "package", range: "1000", trigger: "nightly")

    assert_response :success
    assert_select "select[name=type] option[selected][value=vulnerability]"
    assert_select "select[name=range] option[selected][value='90']"
    assert_select "select[name=trigger] option[selected][value='']"
  end
end
