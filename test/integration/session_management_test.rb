require "test_helper"

# Server-side sessions (ADR 0006, ASVS V7).
class SessionManagementTest < ActionDispatch::IntegrationTest
  test "signing out ends the session on the server, a copied cookie no longer works" do
    sign_in
    copied = cookies.to_hash

    delete logout_path
    copied.each { |name, value| cookies[name] = value }
    get root_path

    assert_redirected_to login_path
  end

  test "signing in again ends the session the browser held before" do
    sign_in
    copied = cookies.to_hash

    sign_in
    copied.each { |name, value| cookies[name] = value }
    get root_path

    assert_redirected_to login_path
    assert_equal 1, users(:alice).sessions.count
  end

  test "the session cookie is signed with HMAC-SHA256" do
    sign_in
    data, digest = CGI.unescape(cookies[:session_id]).split("--")
    key = Rails.application.key_generator.generate_key(Rails.application.config.action_dispatch.signed_cookie_salt)

    assert_equal OpenSSL::HMAC.hexdigest("SHA256", key, data), digest
  end

  test "sessions end after an hour without activity" do
    sign_in

    travel 50.minutes do
      get root_path
      assert_response :success
    end
    travel 105.minutes do
      get root_path
      assert_response :success
    end
    travel 170.minutes do
      get root_path
      assert_redirected_to login_path
    end
  end

  test "active sessions still end after the maximum age" do
    sign_in
    start = Time.current

    (1..9).each do |step|
      travel_to start + (step * 50).minutes
      get root_path
      assert_response :success
    end
    travel_to start + Rails.configuration.x.session_max_age + 1.minute
    get root_path

    assert_redirected_to login_path
  ensure
    travel_back
  end

  test "users see their sessions and end another one" do
    other = users(:alice).sessions.create!(user_agent: "Other browser", ip_address: "192.0.2.1")
    users(:alice).sessions.create!(user_agent: "Expired browser", updated_at: 2.hours.ago)
    users(:bob).sessions.create!(user_agent: "Bob browser")
    sign_in

    get active_sessions_path
    assert_select "td", text: "Other browser"
    assert_select "td", text: "Expired browser", count: 0
    assert_select "td", text: "Bob browser", count: 0

    delete active_session_path(other)
    assert_not Session.exists?(other.id)
    get root_path
    assert_response :success
  end

  test "users cannot end sessions of others" do
    foreign = users(:bob).sessions.create!
    sign_in

    delete active_session_path(foreign)

    assert_response :not_found
    assert Session.exists?(foreign.id)
  end

  test "admins end all sessions of a user" do
    users(:alice).sessions.create!
    sign_in(sub: "root-sub", groups: [ "trivista-users", "trivista-admins" ])

    patch end_sessions_admin_user_path(users(:alice))

    assert_empty users(:alice).sessions.reload
  end

  test "non-admins cannot end sessions of others" do
    users(:alice).sessions.create!
    sign_in(sub: "dave-sub")

    patch end_sessions_admin_user_path(users(:alice))

    assert_response :not_found
    assert_not_empty users(:alice).sessions
  end

  test "deactivation removes the sessions" do
    users(:alice).sessions.create!

    users(:alice).deactivate!

    assert_empty users(:alice).sessions
  end

  test "a login callback carrying its own PKCE verifier or nonce is rejected" do
    get "/auth/openid_connect/callback", params: { code: "x", state: "y", code_verifier: "attacker" }
    assert_response :bad_request

    get "/auth/openid_connect/callback", params: { code: "x", state: "y", nonce: "attacker" }
    assert_response :bad_request

    get "/auth/openid_connect/callback/", params: { code: "x", state: "y", code_verifier: "attacker" }
    assert_response :bad_request
  end

  test "the identity provider is asked for a recent sign-in and older ones are rejected" do
    assert_equal Rails.configuration.x.session_max_age.to_i, OIDC_OPTIONS[:extra_authorize_params][:max_age]

    sign_in("auth_time" => 9.hours.ago.to_i)
    assert_response :forbidden
  end

  test "sessions of a deactivated user stop working even if they were not removed" do
    sign_in
    users(:alice).update_column(:deactivated_at, Time.current)

    get root_path

    assert_redirected_to login_path
  end
end
