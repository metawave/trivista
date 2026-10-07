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
    get branch_path(branches(:shop_backend_main), type: "package", range: "1000")

    assert_response :success
    assert_select ".tab[aria-current=page]", text: "Vulnerabilities"
    assert_select ".segmented a[aria-current=true]", text: "90d"
  end

  test "filter links keep the other filters" do
    get branch_path(branches(:shop_backend_main), type: "secret", range: "7")

    assert_select ".segmented a[href=?]", branch_path(branches(:shop_backend_main), type: "secret", range: "30")
    assert_select ".tab[href=?]", branch_path(branches(:shop_backend_main), type: "vulnerability", range: "7")
  end

  test "lists the scans with trigger and diff" do
    get branch_path(branches(:shop_backend_main))

    assert_select "tbody tr", 1 do
      assert_select "a[href=?]", scan_path(scans(:shop_main_first)), text: "01234567"
      assert_select ".chip", text: "push"
      assert_select "td", text: "first scan"
    end
  end
end
