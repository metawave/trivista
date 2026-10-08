require "test_helper"

class AdminUsersTest < ActionDispatch::IntegrationTest
  test "only admins reach user administration" do
    sign_in(sub: "dave-sub")

    get admin_users_path

    assert_response :not_found
  end

  test "admins deactivate and reactivate users" do
    sign_in(sub: "root-sub", groups: [ "trivista-users", "trivista-admins" ])
    get admin_users_path
    assert_response :success

    patch deactivate_admin_user_path(users(:alice))
    assert users(:alice).reload.deactivated?
    assert upload_tokens(:alice_ci_token).reload.revoked_at

    patch reactivate_admin_user_path(users(:alice))
    assert_not users(:alice).reload.deactivated?
  end

  test "break-glass admins cannot be deactivated" do
    break_glass = User.create!(iss: "https://idp.example.com", sub: "break-glass-sub")
    sign_in(sub: "root-sub", groups: [ "trivista-users", "trivista-admins" ])

    patch deactivate_admin_user_path(break_glass)

    assert_response :unprocessable_content
    assert_not break_glass.reload.deactivated?
  end

  test "admins cannot deactivate themselves" do
    sign_in(sub: "root-sub", groups: [ "trivista-users", "trivista-admins" ])
    get admin_users_path
    assert_select "tbody tr", text: /root-sub/ do
      assert_select "button", text: "Deactivate", count: 0
    end

    patch deactivate_admin_user_path(users(:root))

    assert_response :unprocessable_content
    assert_not users(:root).reload.deactivated?
  end
end
