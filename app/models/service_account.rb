class ServiceAccount < ApplicationRecord
  belongs_to :owner
  has_many :upload_tokens, dependent: :restrict_with_exception
  has_many :scans, dependent: :restrict_with_exception

  scope :manageable_by, ->(user) { user.admin? ? all : where(owner: Owner.managed_by(user)) }

  validates :name, presence: true, uniqueness: { scope: :owner_id }
end
