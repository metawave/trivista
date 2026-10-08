require "test_helper"

class RepoPageTest < ActionDispatch::IntegrationTest
  setup do
    @repo = repos(:shop_backend)
    @main = branches(:shop_backend_main)
    @repo.update!(default_branch: @main)
    @scan = scans(:shop_main_first)
    @scan.update!(counts: { "vulnerability" => { "HIGH" => 3 } }, created_at: 1.day.ago)
    sign_in(sub: "dave-sub")
  end

  test "old branch links lead to the repo with that branch" do
    get branch_path(@main)

    assert_redirected_to repo_path(@repo, branch: "main")
  end

  test "shows the current findings of the default branch with branch switch and last scan" do
    feature = @repo.branches.create!(name: "feature/x")

    get repo_path(@repo)

    assert_response :success
    assert_select ".dropdown__value", text: "main"
    assert_select ".dropdown__menu a[href=?]", repo_path(@repo, branch: "feature/x"), text: /feature\/x/
    assert_select ".header-card a[href=?]", scan_path(@scan), text: "01234567"
    assert_select ".tab[aria-current=page]", text: /Vulnerabilities\s*3/
    assert_select "tbody.current tr#finding_#{findings(:openssl_cve).id} .origin", text: @scan.artifact.name

    get repo_path(@repo, branch: feature.name)
    assert_select ".dropdown__value", text: "feature/x"
    assert_select "tbody.current tr", 0
  end

  test "unknown branches answer not found" do
    get repo_path(@repo, branch: "nope")

    assert_response :not_found
  end

  test "current findings skip artifacts outside the activity window" do
    @scan.update!(created_at: 31.days.ago)

    get repo_path(@repo)

    assert_select ".tab", text: /Vulnerabilities\s*0/
    assert_select "tbody.current tr", 0
  end

  test "only new compares each artifact with its predecessor" do
    previous = Scan.create!(branch: @main, artifact: @scan.artifact, service_account: @scan.service_account, commit_sha: "0ld",
      reported_artifact_type: "container_image", reported_artifact_name: "x", created_at: 2.days.ago)
    fresh = projects(:shop).findings.create!(finding_type: "vulnerability", identifier: "CVE-2024-9999", fingerprint: "fresh")
    @scan.occurrences.create!(finding: fresh, severity: "LOW")
    previous.occurrences.create!(finding: findings(:openssl_cve), severity: "HIGH")

    get repo_path(@repo, only_new: "1")

    assert_select "tbody.current tr", 1
    assert_select "tr#finding_#{fresh.id} .marker", text: "NEW"
  end

  test "lists findings no longer reported per artifact" do
    previous = Scan.create!(branch: @main, artifact: @scan.artifact, service_account: @scan.service_account, commit_sha: "0ld",
      reported_artifact_type: "container_image", reported_artifact_name: "x", created_at: 2.days.ago)
    gone = projects(:shop).findings.create!(finding_type: "vulnerability", identifier: "CVE-2023-0001", fingerprint: "gone")
    previous.occurrences.create!(finding: gone, severity: "MEDIUM")

    get repo_path(@repo)

    assert_select "#no-longer-reported tbody.no-longer-reported tr#finding_#{gone.id} .origin", text: @scan.artifact.name
    assert_select "tbody.current tr#finding_#{gone.id}", 0
  end

  test "the scans view renders one chart per artifact and lists the scans" do
    get repo_path(@repo, view: "scans")

    assert_select ".tab[aria-current=page]", text: /Scans\s*1/
    points = JSON.parse(css_select("[data-controller=trend]").sole["data-trend-points-value"])
    assert_equal [ { "HIGH" => 3 } ], points.map { it["counts"] }
    assert_select ".trend tbody tr", 1 do
      assert_select "a[href=?]", scan_path(@scan), text: "01234567"
      assert_select ".chip", text: "push"
      assert_select "td", text: "first scan"
    end
  end

  test "scans view filters keep the other filters and reject unknown values" do
    get repo_path(@repo, view: "scans", type: "package", range: "1000")
    assert_select ".segmented a[aria-current=true]", text: "90d"

    get repo_path(@repo, view: "scans", type: "secret", range: "7")
    points = JSON.parse(css_select("[data-controller=trend]").sole["data-trend-points-value"])
    assert_equal [ {} ], points.map { it["counts"] }
    assert_select ".segmented a[href=?]", repo_path(@repo, view: "scans", type: "secret", range: "30")
  end
end
