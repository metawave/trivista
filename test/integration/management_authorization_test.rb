require "test_helper"

# Management routes answer 404 to users who may see a project but not manage it (ADR 0007).
class ManagementAuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    @repo = projects(:alice_shared).repos.create!(name: "shared-repo")
    @main = @repo.branches.create!(name: "main")
    @feature = @repo.branches.create!(name: "feature")
    @repo.update!(default_branch: @main)
    artifact = projects(:alice_shared).artifacts.create!(category: "source", name: ".")
    @scan = Scan.create!(branch: @main, artifact:, service_account: service_accounts(:alice_ci), commit_sha: "c0ffee",
      reported_artifact_type: "filesystem", reported_artifact_name: ".")
    sign_in(sub: "dave-sub")
  end

  test "a viewer sees the shared repo" do
    get repo_path(@repo)

    assert_response :success
  end

  test "a viewer cannot change the default branch" do
    patch repo_path(@repo), params: { repo: { default_branch_id: @feature.id } }

    assert_response :not_found
    assert_equal @main, @repo.reload.default_branch
  end

  test "a manager cannot point the default branch at a branch of another repo" do
    sign_in

    patch repo_path(@repo), params: { repo: { default_branch_id: branches(:shop_backend_main).id } }

    assert_response :not_found
    assert_equal @main, @repo.reload.default_branch
  end

  test "a viewer cannot delete repos, branches or scans" do
    delete repo_path(@repo), params: { confirmation: @repo.name }
    assert_response :not_found
    delete branch_path(@feature), params: { confirmation: @feature.name }
    assert_response :not_found
    delete scan_path(@scan)
    assert_response :not_found

    assert [ @repo, @feature, @scan ].all? { it.class.exists?(it.id) }
  end

  test "service accounts of others stay hidden and get no tokens" do
    get service_account_path(service_accounts(:alice_ci))
    assert_response :not_found

    assert_no_difference "UploadToken.count" do
      post service_account_upload_tokens_path(service_accounts(:alice_ci)), params: { upload_token: { expires_on: 30.days.from_now.to_date.iso8601 } }
    end
    assert_response :not_found
  end

  test "only admins deactivate and reactivate users" do
    patch deactivate_admin_user_path(users(:alice))
    assert_response :not_found
    assert_not users(:alice).reload.deactivated?

    users(:bob).deactivate!
    patch reactivate_admin_user_path(users(:bob))
    assert_response :not_found
    assert users(:bob).reload.deactivated?
  end

  test "state changes without a CSRF token are rejected" do
    sign_in(sub: "alice-sub")
    ActionController::Base.allow_forgery_protection = true

    delete repo_path(@repo), params: { confirmation: @repo.name }

    assert_response :unprocessable_content
    assert Repo.exists?(@repo.id)
  ensure
    ActionController::Base.allow_forgery_protection = false
  end
end
