require "test_helper"

# Security-relevant actions are reported as structured events with their actor (ASVS V16.3, ADR 0010).
class AuditEventsTest < ActionDispatch::IntegrationTest
  test "sign-in, rejected sign-in and sign-out" do
    assert_event_reported("trivista.login", payload: { user_id: users(:alice).id }) { sign_in }
    assert_event_reported("trivista.logout", payload: { user_id: users(:alice).id }) { delete logout_path }
    assert_event_reported("trivista.login_rejected", payload: { reason: "not a member of the login group" }) do
      sign_in(sub: "carol-sub", groups: [ "other" ])
    end
  end

  test "a login callback carrying its own verifier" do
    assert_event_reported("trivista.login_rejected", payload: { reason: "callback carries its own verifier or nonce" }) do
      get "/auth/openid_connect/callback", params: { code: "x", state: "y", code_verifier: "attacker" }
    end
  end

  test "token issued and revoked" do
    sign_in(sub: "dave-sub")
    service_account = service_accounts(:shop_ci)

    event = assert_event_reported("trivista.token_created", payload: { service_account_id: service_account.id }) do
      post service_account_upload_tokens_path(service_account), params: { upload_token: { expires_on: 30.days.from_now.to_date.iso8601 } }
    end
    assert_equal users(:dave).id, event[:context][:user_id]

    assert_event_reported("trivista.token_revoked", payload: { id: upload_tokens(:shop_ci_token).id }) do
      delete upload_token_path(upload_tokens(:shop_ci_token))
    end
  end

  test "deletions and visibility changes" do
    sign_in(sub: "dave-sub")

    assert_event_reported("trivista.deleted", payload: { record: "Scan", id: scans(:shop_main_first).id }) do
      delete scan_path(scans(:shop_main_first))
    end
    assert_event_reported("trivista.visibility_changed", payload: { project_id: projects(:shop).id, visibility: "public" }) do
      patch project_path(projects(:shop)), params: { project: { visibility: "public" } }
    end
  end

  test "admin actions on users" do
    sign_in(sub: "root-sub", groups: [ "trivista-users", "trivista-admins" ])

    assert_event_reported("trivista.user_deactivated", payload: { target_user_id: users(:alice).id }) do
      patch deactivate_admin_user_path(users(:alice))
    end
    assert_event_reported("trivista.sessions_ended", payload: { target_user_id: users(:alice).id }) do
      patch end_sessions_admin_user_path(users(:alice))
    end
  end

  test "denied access to records outside the scope" do
    sign_in(sub: "bob-sub", groups: [ "trivista-users" ])

    assert_event_reported("trivista.not_found", payload: { path: project_path(projects(:shop)) }) do
      get project_path(projects(:shop))
    end
  end

  test "uploads and rejected upload tokens" do
    assert_event_reported("trivista.upload_rejected", payload: { reason: "token" }) do
      post api_scans_path, headers: { "Authorization" => "Bearer trv_unknown" }
    end
  end
end
