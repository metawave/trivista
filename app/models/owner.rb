class Owner < ApplicationRecord
  belongs_to :user, optional: true
  has_many :projects, dependent: :restrict_with_exception
  has_many :service_accounts, dependent: :restrict_with_exception

  def user?
    user_id.present?
  end

  def display_name
    user? ? user.name || user.sub : group_name
  end
end
