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
end
