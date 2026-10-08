require "test_helper"

class ProjectListTest < ActionDispatch::IntegrationTest
  test "lists visible projects with their owner and links" do
    sign_in(sub: "dave-sub")

    get root_path

    assert_response :success
    assert_select "a[href=?]", project_path(projects(:shop)), text: "shop"
    assert_select "a[href=?]", project_path(projects(:alice_shared)), text: "shared"
    assert_select "a[href=?]", project_path(projects(:alice_tools)), count: 0
    assert_select "tr", text: /shop.*team-a/m
    assert_select "tr", text: /shared.*Alice/m
  end

  test "shows the current counts per finding type and severity" do
    repos(:shop_backend).update!(default_branch: branches(:shop_backend_main))
    scans(:shop_main_first).update!(counts: { "vulnerability" => { "CRITICAL" => 2, "HIGH" => 3 }, "secret" => { "HIGH" => 1 } },
      created_at: 1.hour.ago)
    sign_in(sub: "dave-sub")

    get root_path

    assert_select "tr#project_#{projects(:shop).id}" do
      assert_select "td.vulnerability", text: /CRITICAL\s*2.*HIGH\s*3/m
      assert_select "td.secret", text: /HIGH\s*1/
      assert_select "td.misconfiguration", text: "–"
    end
  end

  test "filters by name and visibility" do
    sign_in(sub: "dave-sub")

    get root_path(q: "SHA")
    assert_select "tbody tr", 1
    assert_select "a", text: "shared"

    get root_path(visibility: "public")
    assert_select "tbody tr td:first-child a", text: /\A(public|open)\z/, count: 2
    assert_select ".segmented a[aria-current=true]", text: "public"

    get root_path(q: "%")
    assert_select "tbody tr", 0
  end

  test "shows repo count and the last scan of each project" do
    scans(:shop_main_first).update!(created_at: 2.hours.ago)
    sign_in(sub: "dave-sub")

    get root_path

    assert_select "tr#project_#{projects(:shop).id}" do
      assert_select "td", text: /1 repo/
      assert_select "time", text: "about 2 hours ago"
    end
    assert_select "tr#project_#{projects(:alice_shared).id} td.num", text: "never"
  end

  test "the overview sums the listed projects and ranks the most widespread vulnerabilities" do
    repos(:shop_backend).update!(default_branch: branches(:shop_backend_main))
    repos(:alice_tools_cli).update!(default_branch: branches(:alice_tools_cli_main))
    scans(:shop_main_first).update!(counts: { "vulnerability" => { "HIGH" => 1 } }, created_at: 1.hour.ago)
    scans(:alice_tools_first).update!(counts: { "vulnerability" => { "HIGH" => 2 } }, created_at: 1.hour.ago)
    sign_in(sub: "alice-sub")

    get root_path

    assert_select ".tile", text: /Vulnerabilities\s*3/
    assert_select ".widespread li", text: /#{findings(:openssl_cve).identifier}.*1\s*project/m
    points = JSON.parse(css_select("[data-controller=trend]").sole["data-trend-points-value"])
    assert_equal({ "HIGH" => 3 }, points.last["counts"])

    get root_path(q: "tools", trend: "secret")
    assert_select ".tile", text: /Vulnerabilities\s*2/
    assert_select ".segmented a[href=?]", root_path(q: "tools", trend: "secret", range: "7"), text: "7d"
    assert_select ".segmented a[href=?]", root_path(q: "tools", visibility: "user", trend: "secret"), text: "user"
  end
end
