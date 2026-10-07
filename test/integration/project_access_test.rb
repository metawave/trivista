require "test_helper"

class ProjectAccessIntegrationTest < ActionDispatch::IntegrationTest
  test "anonymous access is redirected to the login, also for public projects" do
    [ project_path(projects(:alice_public)), project_path(projects(:shop)) ].each do |path|
      get path

      assert_redirected_to login_path
    end
  end

  test "all routes of a visible project respond" do
    sign_in(sub: "alice-sub")

    each_path_of(projects(:alice_tools), repos(:alice_tools_cli), branches(:alice_tools_cli_main), scans(:alice_tools_first)) do |path|
      get path

      assert_response :success, path
    end
  end

  test "all routes of a hidden project answer not found" do
    sign_in(sub: "dave-sub")

    each_path_of(projects(:alice_tools), repos(:alice_tools_cli), branches(:alice_tools_cli_main), scans(:alice_tools_first)) do |path|
      get path

      assert_response :not_found, path
    end
  end

  test "admins reach every project" do
    sign_in(sub: "root-sub", groups: [ "trivista-users", "trivista-admins" ])

    get scan_path(scans(:alice_tools_first))

    assert_response :success
  end

  private
    def each_path_of(project, repo, branch, scan, &)
      [ project_path(project), repo_path(repo), branch_path(branch), scan_path(scan) ].each(&)
    end
end
