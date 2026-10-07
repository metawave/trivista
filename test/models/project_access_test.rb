require "test_helper"

class ProjectAccessTest < ActiveSupport::TestCase
  VISIBLE = {
    alice: %i[shop team_a_public alice_tools alice_shared alice_public],
    dave: %i[shop team_a_public alice_shared alice_public],
    bob: %i[team_a_public alice_public],
    root: %i[shop team_a_public alice_tools alice_shared alice_public]
  }.freeze

  MANAGEABLE = {
    alice: %i[shop team_a_public alice_tools alice_shared alice_public],
    dave: %i[shop team_a_public],
    bob: %i[],
    root: %i[shop team_a_public alice_tools alice_shared alice_public]
  }.freeze

  test "visibility matrix" do
    VISIBLE.each do |user, expected|
      assert_equal expected.map { projects(it) }.sort_by(&:id), Project.visible_to(users(user)).sort_by(&:id), user
    end
  end

  test "management matrix" do
    MANAGEABLE.each do |user, expected|
      assert_equal expected.map { projects(it) }.sort_by(&:id), Project.manageable_by(users(user)).sort_by(&:id), user
    end
  end

  test "nested resources follow the visibility of their project" do
    assert_includes Scan.visible_to(users(:alice)), scans(:alice_tools_first)
    assert_not_includes Scan.visible_to(users(:dave)), scans(:alice_tools_first)
    assert_not_includes Branch.visible_to(users(:bob)), branches(:shop_backend_main)
    assert_not_includes Repo.visible_to(users(:bob)), repos(:shop_backend)
  end

  test "a group project stays visible to its group after the owner lost it" do
    users(:alice).update!(groups: [ "trivista-users" ])

    assert_includes Project.visible_to(users(:dave)), projects(:alice_shared)
  end

  test "the visibility group of a user project must be one of the owner's current groups" do
    project = projects(:alice_tools)

    assert project.update(visibility: "group", visibility_group: "team-a")
    assert_not project.update(visibility_group: "team-z")
    assert_includes project.errors[:visibility_group], "must be one of the owner's current groups"
  end

  test "group visibility of a user project needs a group" do
    assert_not projects(:alice_tools).update(visibility: "group", visibility_group: nil)
  end

  test "group projects are always visible to their owner group only" do
    assert_not projects(:shop).update(visibility_group: "team-z")
  end
end
