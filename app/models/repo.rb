class Repo < ApplicationRecord
  belongs_to :project
  belongs_to :default_branch, class_name: "Branch", optional: true
  has_many :branches, dependent: :delete_all
end
