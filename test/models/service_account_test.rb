require "test_helper"

class ServiceAccountTest < ActiveSupport::TestCase
  test "name is unique per owner" do
    duplicate = ServiceAccount.new(owner: owners(:team_a), name: "ci")

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "cannot be deleted while scans reference it" do
    assert_raises(ActiveRecord::InvalidForeignKey) { service_accounts(:shop_ci).delete }
  end
end
