require "test_helper"

class ArtifactTest < ActiveSupport::TestCase
  test "identity is unique per project, category and name" do
    duplicate = Artifact.new(project: projects(:shop), category: "container_image", name: "registry.example.com/shop")

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "filesystem and repository are not categories of their own" do
    artifact = artifacts(:shop_image)

    assert_raises(ActiveRecord::StatementInvalid) { artifact.update_column(:category, "filesystem") }
    assert_raises(ActiveRecord::StatementInvalid) { artifact.update_column(:category, "repository") }
  end
end
