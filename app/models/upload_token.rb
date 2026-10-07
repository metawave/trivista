class UploadToken < ApplicationRecord
  belongs_to :service_account
  belongs_to :created_by, class_name: "User"

  scope :usable, -> { where(revoked_at: nil).where(expires_at: Time.current..) }

  def self.digest(secret)
    Digest::SHA256.hexdigest(secret)
  end
end
