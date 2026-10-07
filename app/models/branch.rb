class Branch < ApplicationRecord
  belongs_to :repo
  has_many :scans, dependent: :delete_all

  scope :visible_to, ->(user) { where(repo: Repo.visible_to(user)) }
end
