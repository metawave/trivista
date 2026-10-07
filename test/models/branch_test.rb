require "test_helper"

class BranchTest < ActiveSupport::TestCase
  test "name is unique per repo" do
    duplicate = Branch.new(repo: repos(:shop_backend), name: "main")

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end
end
