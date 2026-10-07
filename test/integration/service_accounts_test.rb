require "test_helper"

class ServiceAccountsTest < ActionDispatch::IntegrationTest
  test "lists own and group service accounts only" do
    sign_in(sub: "bob-sub", groups: [ "trivista-users" ])

    get service_accounts_path

    assert_response :success
    assert_select "a[href=?]", service_account_path(service_accounts(:shop_ci)), count: 0
    assert_select "a[href=?]", service_account_path(service_accounts(:alice_ci)), count: 0
  end

  test "creates service accounts for the user and for own groups only" do
    sign_in(sub: "dave-sub")
    get new_service_account_path
    assert_response :success

    post service_accounts_path, params: { service_account: { name: "personal", owner: "user" } }
    assert_equal owners_for(users(:dave)), ServiceAccount.last.owner

    post service_accounts_path, params: { service_account: { name: "team", owner: "group:team-a" } }
    assert_equal owners(:team_a), ServiceAccount.last.owner

    assert_no_difference "ServiceAccount.count" do
      post service_accounts_path, params: { service_account: { name: "foreign", owner: "group:team-z" } }
    end
    assert_response :unprocessable_content
  end

  test "issues a token with mandatory expiry and shows the secret once" do
    sign_in(sub: "dave-sub")

    post service_account_upload_tokens_path(service_accounts(:shop_ci)), params: { upload_token: { expires_on: 30.days.from_now.to_date } }

    assert_response :success
    secret = css_select("code.token-secret").first.text
    token = UploadToken.find_by!(token_digest: UploadToken.digest(secret))
    assert_equal users(:dave), token.created_by

    get service_account_path(service_accounts(:shop_ci))
    assert_response :success
    assert_no_match secret, response.body
  end

  test "rejects missing and too long token lifetimes" do
    sign_in(sub: "dave-sub")

    [ nil, (Rails.configuration.x.token_max_lifetime + 2.days).from_now.to_date ].each do |expires_on|
      assert_no_difference "UploadToken.count" do
        post service_account_upload_tokens_path(service_accounts(:shop_ci)), params: { upload_token: { expires_on: } }
      end
      assert_response :unprocessable_content
    end
  end

  test "revokes tokens of manageable service accounts only" do
    sign_in(sub: "bob-sub", groups: [ "trivista-users" ])
    delete upload_token_path(upload_tokens(:shop_ci_token))
    assert_response :not_found
    assert_nil upload_tokens(:shop_ci_token).reload.revoked_at

    sign_in(sub: "dave-sub")
    delete upload_token_path(upload_tokens(:shop_ci_token))
    assert upload_tokens(:shop_ci_token).reload.revoked_at
  end

  private
    def owners_for(user)
      Owner.find_by!(user:)
    end
end
