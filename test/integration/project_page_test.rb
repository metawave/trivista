require "test_helper"

class ProjectPageTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:shop)
    @repo = repos(:shop_backend)
    @main = branches(:shop_backend_main)
    @repo.update!(default_branch: @main)
    @scan = scans(:shop_main_first)
    @scan.update!(counts: { "vulnerability" => { "HIGH" => 1 } }, created_at: 1.day.ago)
    sign_in(sub: "dave-sub")
  end

  test "the overview sums the default branches and lists the repos" do
    feature = @repo.branches.create!(name: "feature")
    Scan.create!(branch: feature, artifact: @scan.artifact, service_account: @scan.service_account, commit_sha: "f",
      reported_artifact_type: "container_image", reported_artifact_name: "x", counts: { "vulnerability" => { "CRITICAL" => 9 } })

    get project_path(@project)

    assert_response :success
    assert_select ".tab[aria-current=page]", text: "Overview"
    assert_select ".tab", text: /Vulnerabilities\s*1/
    assert_select ".tile", text: /Vulnerabilities\s*1/
    assert_select "tr#repo_#{@repo.id}" do
      assert_select "a[href=?]", repo_path(@repo), text: "backend"
      assert_select "td.vulnerability", text: /HIGH\s*1/
    end
    points = JSON.parse(css_select("[data-controller=trend]").sole["data-trend-points-value"])
    assert_equal({ "HIGH" => 1 }, points.last["counts"])
  end

  test "a type tab lists the current findings of all repos with the repos they occur in" do
    get project_path(@project, type: "vulnerability")

    assert_select ".tab[aria-current=page]", text: /Vulnerabilities/
    assert_select "tbody.current tr#finding_#{findings(:openssl_cve).id}" do
      assert_select ".origin a[href=?]", repo_path(@repo), text: "backend"
    end
  end

  test "findings of other branches stay out of the project view" do
    @repo.update!(default_branch: @repo.branches.create!(name: "empty"))

    get project_path(@project, type: "vulnerability")

    assert_select "tbody.current tr", 0
  end
end
