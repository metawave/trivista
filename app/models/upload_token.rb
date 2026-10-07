class UploadToken < ApplicationRecord
  SECRET_PREFIX = "trv_"

  belongs_to :service_account
  belongs_to :created_by, class_name: "User"

  scope :usable, -> { where(revoked_at: nil).where(expires_at: Time.current..) }

  validate :expires_within_max_lifetime, on: :create

  def self.digest(secret)
    Digest::SHA256.hexdigest(secret)
  end

  # Returns the token and its secret; only the digest is stored (ADR 0005).
  def self.issue!(service_account:, created_by:, expires_at:)
    secret = SECRET_PREFIX + SecureRandom.base58(40)
    [ create!(service_account:, created_by:, expires_at:, token_digest: digest(secret)), secret ]
  end

  def revoke!
    update!(revoked_at: Time.current) unless revoked_at
  end

  private
    def expires_within_max_lifetime
      if expires_at.nil?
        errors.add(:expires_at, "can't be blank")
      elsif expires_at <= Time.current || expires_at > Rails.configuration.x.token_max_lifetime.from_now
        errors.add(:expires_at, "must be in the future and at most #{Rails.configuration.x.token_max_lifetime.inspect} away")
      end
    end
end
