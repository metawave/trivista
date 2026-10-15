class Branch < ApplicationRecord
  belongs_to :repo
  has_many :scans, dependent: :delete_all

  validates :name, presence: true, length: { maximum: 255 }, format: { without: /[[:cntrl:]]/ }

  scope :visible_to, ->(user) { where(repo: Repo.visible_to(user)) }
end
