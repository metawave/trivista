class User < ApplicationRecord
  has_one :owner, dependent: :restrict_with_exception
  has_many :created_upload_tokens, class_name: "UploadToken", foreign_key: :created_by_id,
    inverse_of: :created_by, dependent: :restrict_with_exception

  def deactivated?
    deactivated_at.present?
  end
end
