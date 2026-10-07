require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "identity is unique per issuer and subject" do
    duplicate = User.new(iss: users(:alice).iss, sub: users(:alice).sub, name: "Copy")

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "same subject from another issuer is a different user" do
    assert User.create!(iss: "https://other-idp.example.com", sub: users(:alice).sub, name: "Other")
  end

  test "deactivation revokes tokens of own service accounts and tokens the user created" do
    users(:alice).deactivate!

    assert upload_tokens(:alice_ci_token).reload.revoked_at
    assert upload_tokens(:shop_ci_token).reload.revoked_at
  end

  test "reactivation does not restore tokens" do
    users(:alice).deactivate!
    users(:alice).reactivate!

    assert_not users(:alice).deactivated?
    assert upload_tokens(:alice_ci_token).reload.revoked_at
  end

  test "break-glass admins cannot be deactivated" do
    break_glass = User.create!(iss: "https://idp.example.com", sub: "break-glass-sub")

    assert_raises(User::NotDeactivatable) { break_glass.deactivate! }
    assert_not break_glass.reload.deactivated?
  end
end
