class User < ApplicationRecord
  class NotDeactivatable < StandardError; end

  has_one :owner, dependent: :restrict_with_exception
  has_many :created_upload_tokens, class_name: "UploadToken", foreign_key: :created_by_id,
    inverse_of: :created_by, dependent: :restrict_with_exception

  def deactivated?
    deactivated_at.present?
  end

  def break_glass?
    oidc = Rails.configuration.x.oidc
    iss == oidc.issuer && oidc.break_glass_subjects.include?(sub)
  end

  # Revokes permanently; a reactivated user needs new tokens (ADR 0005).
  def deactivate!
    raise NotDeactivatable, "break-glass admins cannot be deactivated" if break_glass?

    transaction do
      lock!
      update!(deactivated_at: Time.current)
      revocable_tokens.update_all(revoked_at: Time.current)
    end
  end

  def reactivate!
    update!(deactivated_at: nil)
  end

  def revoke_tokens_created_for_groups!(group_names)
    return if group_names.empty?

    created_upload_tokens.where(revoked_at: nil)
      .where(service_account: ServiceAccount.where(owner: Owner.where(group_name: group_names)))
      .update_all(revoked_at: Time.current)
  end

  private
    def revocable_tokens
      UploadToken.where(revoked_at: nil)
        .where(created_by: self).or(UploadToken.where(revoked_at: nil, service_account: ServiceAccount.where(owner:)))
    end
end
