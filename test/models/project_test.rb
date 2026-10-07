require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "name is unique per owner" do
    duplicate = Project.new(owner: owners(:team_a), name: "shop", visibility: "group")

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "same name is allowed for another owner" do
    assert Project.create!(owner: owners(:alice), name: "shop", visibility: "user")
  end

  test "visibility is restricted to user, group and public" do
    assert_raises(ActiveRecord::StatementInvalid) { projects(:shop).update_column(:visibility, "everyone") }
  end

  test "visibility user is only valid for user owners" do
    project = Project.new(owner: owners(:team_a), name: "billing", visibility: "user")

    assert_not project.valid?
    assert_includes project.errors[:visibility], "user is only allowed for projects owned by a user"
  end
end
