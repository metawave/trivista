class Repo < ApplicationRecord
  belongs_to :project
  belongs_to :default_branch, class_name: "Branch", optional: true
  has_many :branches, dependent: :delete_all

  scope :visible_to, ->(user) { where(project: Project.visible_to(user)) }

  def add_branch!(name)
    branches.create!(name:).tap { apply_default_branch_rule! }
  end

  # main, then master, then the first uploaded branch, unless set manually (ADR 0008).
  def apply_default_branch_rule!
    with_lock do
      next if default_branch_manual?

      update!(default_branch: branches.find_by(name: "main") || branches.find_by(name: "master") ||
        branches.order(:created_at, :id).first)
    end
  end
end
