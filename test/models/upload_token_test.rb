require "test_helper"

class UploadTokenTest < ActiveSupport::TestCase
  test "digest is unique" do
    duplicate = UploadToken.new(service_account: service_accounts(:shop_ci), created_by: users(:alice),
      token_digest: upload_tokens(:shop_ci_token).token_digest, expires_at: 1.day.from_now)

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "expiry is mandatory" do
    assert_raises(ActiveRecord::NotNullViolation) { upload_tokens(:shop_ci_token).update_column(:expires_at, nil) }
  end
end
