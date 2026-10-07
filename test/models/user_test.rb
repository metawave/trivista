require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "identity is unique per issuer and subject" do
    duplicate = User.new(iss: users(:alice).iss, sub: users(:alice).sub, name: "Copy")

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "same subject from another issuer is a different user" do
    assert User.create!(iss: "https://other-idp.example.com", sub: users(:alice).sub, name: "Other")
  end

  test "deactivated reflects deactivated_at" do
    assert_not users(:alice).deactivated?

    users(:alice).update!(deactivated_at: Time.current)

    assert users(:alice).deactivated?
  end
end
