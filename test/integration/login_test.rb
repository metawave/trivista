require "test_helper"

class LoginTest < ActionDispatch::IntegrationTest
  test "pages require a login" do
    get root_path

    assert_redirected_to login_path
  end

  test "signing in creates the user with groups from the claim" do
    sign_in(sub: "carol-sub", groups: [ "team-c", "trivista-users" ], "name" => "Carol")

    user = User.find_by!(iss: "https://idp.example.com", sub: "carol-sub")
    assert_redirected_to root_path
    assert_equal [ "team-c", "trivista-users" ], user.groups
    assert_equal "Carol", user.name
    assert_not user.admin?
  end

  test "the admin group grants the admin role" do
    sign_in(groups: [ "trivista-users", "trivista-admins" ])

    assert users(:alice).reload.admin?
  end

  test "a login without the groups claim is aborted without changes" do
    assert_no_changes -> { users(:alice).reload.attributes } do
      sign_in(groups: nil)
    end

    assert_response :forbidden
  end

  test "a login with a groups overage marker is aborted without changes" do
    assert_no_changes -> { users(:alice).reload.attributes } do
      sign_in("_claim_names" => { "groups" => "src1" })
    end

    assert_response :forbidden
  end

  test "a user outside the login group is rejected and deactivated" do
    sign_in(groups: [ "team-a" ])

    assert_response :forbidden
    assert users(:alice).reload.deactivated?
    assert_not UploadToken.usable.exists?(created_by: users(:alice))
  end

  test "a new account outside the login group is not created" do
    assert_no_difference "User.count" do
      sign_in(sub: "mallory-sub", groups: [ "other" ])
    end
  end

  test "losing a group revokes the tokens created in that group's service accounts" do
    own_token = UploadToken.create!(service_account: service_accounts(:alice_ci), created_by: users(:alice),
      token_digest: UploadToken.digest("alice-second"), expires_at: 1.day.from_now)

    sign_in(groups: [ "trivista-users" ])

    assert upload_tokens(:shop_ci_token).reload.revoked_at
    assert_nil own_token.reload.revoked_at
  end

  test "a deactivated user cannot sign in" do
    users(:alice).deactivate!

    sign_in

    assert_response :forbidden
  end

  test "break-glass admins bypass the login group and the groups claim" do
    sign_in(sub: "break-glass-sub", groups: nil)

    assert_redirected_to root_path
    assert User.find_by!(sub: "break-glass-sub").admin?
  end

  test "sessions expire after the maximum age" do
    sign_in

    travel Rails.configuration.x.session_max_age + 1.minute do
      get root_path

      assert_redirected_to login_path
    end
  end

  test "deactivation ends a running session" do
    sign_in
    users(:alice).deactivate!

    get root_path

    assert_redirected_to login_path
  end

  test "signing out ends the session" do
    sign_in
    delete logout_path

    get root_path
    assert_redirected_to login_path
  end

  test "the login request only accepts POST" do
    get "/auth/openid_connect"

    assert_response :not_found
  end

  test "the login request requires a CSRF token" do
    ActionController::Base.allow_forgery_protection = true
    post "/auth/openid_connect"

    assert_redirected_to %r{\A#{Regexp.escape(auth_failure_url)}\?message=ActionController%3A%3AInvalidAuthenticityToken}
  ensure
    ActionController::Base.allow_forgery_protection = false
  end
end
