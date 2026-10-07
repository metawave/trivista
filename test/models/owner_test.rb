require "test_helper"

class OwnerTest < ActiveSupport::TestCase
  test "owner is either a user or a group" do
    assert_raises(ActiveRecord::StatementInvalid) { Owner.new.save!(validate: false) }
    assert_raises(ActiveRecord::StatementInvalid) do
      Owner.new(user: users(:bob), group_name: "team-b").save!(validate: false)
    end
  end

  test "a user and a group each have at most one owner" do
    assert_raises(ActiveRecord::RecordNotUnique) { Owner.new(user: users(:alice)).save!(validate: false) }
    assert_raises(ActiveRecord::RecordNotUnique) { Owner.new(group_name: "team-a").save!(validate: false) }
  end

  test "occurrence count starts at zero and cannot become negative" do
    owner = Owner.create!(group_name: "team-b")

    assert_equal 0, owner.occurrence_count
    assert_raises(ActiveRecord::StatementInvalid) { owner.update_column(:occurrence_count, -1) }
  end
end
