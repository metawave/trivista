require "test_helper"

class RepoTest < ActiveSupport::TestCase
  test "name is unique per project" do
    duplicate = Repo.new(project: projects(:shop), name: "backend")

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "default branch is not manually set by default" do
    assert_not repos(:shop_backend).default_branch_manual?
  end
end
