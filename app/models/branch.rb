class Branch < ApplicationRecord
  belongs_to :repo
  has_many :scans, dependent: :delete_all
end
