require "test_helper"

class ProjectManagementTest < ActionDispatch::IntegrationTest
  test "managers see the settings page, others get not found" do
    sign_in(sub: "dave-sub")
    get edit_project_path(projects(:shop))
    assert_response :success

    get edit_project_path(projects(:alice_shared))
    assert_response :not_found
  end

  test "visible but not manageable projects allow no management action" do
    sign_in(sub: "dave-sub")
    project = projects(:alice_shared)

    patch project_path(project), params: { project: { visibility: "public" } }
    assert_response :not_found
    delete project_path(project), params: { confirmation: project.name }
    assert_response :not_found

    assert_equal "group", project.reload.visibility
  end

  test "owner changes visibility within own groups" do
    sign_in(sub: "alice-sub")
    project = projects(:alice_tools)

    patch project_path(project), params: { project: { visibility: "group", visibility_group: "team-a" } }
    assert_equal [ "group", "team-a" ], project.reload.values_at(:visibility, :visibility_group)

    patch project_path(project), params: { project: { visibility_group: "team-z" } }
    assert_response :unprocessable_content
    assert_equal "team-a", project.reload.visibility_group
  end

  test "deletion needs the typed name and adjusts the owner quota" do
    sign_in(sub: "dave-sub")
    project = projects(:shop)
    finding_id = findings(:openssl_cve).id
    owners(:team_a).update!(occurrence_count: 10)

    delete project_path(project), params: { confirmation: "wrong" }
    assert Project.exists?(project.id)

    delete project_path(project), params: { confirmation: "shop" }
    assert_redirected_to root_path
    assert_not Project.exists?(project.id)
    assert_equal 10 - 1, owners(:team_a).reload.occurrence_count
    assert_not Finding.exists?(finding_id)
  end

  test "deleting a scan removes its occurrences and orphaned findings only" do
    sign_in(sub: "dave-sub")
    scan = scans(:shop_main_first)
    orphan_id = findings(:openssl_cve).id
    shared = projects(:shop).findings.create!(finding_type: "secret", identifier: "rule", fingerprint: "shared")
    other_scan = Scan.create!(branch: scan.branch, artifact: scan.artifact, service_account: scan.service_account,
      commit_sha: "other", reported_artifact_type: "container_image", reported_artifact_name: "x")
    scan.occurrences.create!(finding: shared, severity: "HIGH")
    other_scan.occurrences.create!(finding: shared, severity: "HIGH")
    owners(:team_a).update!(occurrence_count: 3)

    delete scan_path(scan)

    assert_not Scan.exists?(scan.id)
    assert_not Finding.exists?(orphan_id)
    assert Finding.exists?(shared.id)
    assert_equal 1, owners(:team_a).reload.occurrence_count
  end

  test "a manually set default branch can be chosen and falls back to the rule when deleted" do
    sign_in(sub: "dave-sub")
    repo = repos(:shop_backend)
    develop = repo.branches.create!(name: "develop")

    patch repo_path(repo), params: { repo: { default_branch_id: develop.id } }
    assert_equal [ develop.id, true ], repo.reload.values_at(:default_branch_id, :default_branch_manual)

    delete branch_path(develop), params: { confirmation: "develop" }
    assert_equal [ branches(:shop_backend_main).id, false ], repo.reload.values_at(:default_branch_id, :default_branch_manual)
  end

  test "repositories are deleted with their branches and scans" do
    sign_in(sub: "dave-sub")
    repo_id = repos(:shop_backend).id
    scan_id = scans(:shop_main_first).id

    delete repo_path(repo_id), params: { confirmation: "backend" }

    assert_not Repo.exists?(repo_id)
    assert_not Scan.exists?(scan_id)
  end
end
