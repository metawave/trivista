class ServiceAccount < ApplicationRecord
  belongs_to :owner
  has_many :upload_tokens, dependent: :restrict_with_exception
  has_many :scans, dependent: :restrict_with_exception
end
