class Project < ApplicationRecord
  belongs_to :owner
  has_many :repos, dependent: :delete_all
  has_many :artifacts, dependent: :delete_all
  has_many :findings, dependent: :delete_all

  enum :visibility, { user: "user", group: "group", public: "public" }, prefix: :visible_to, validate: true

  # Owner user, members of the owner group and admins manage a project (ADR 0007).
  scope :manageable_by, ->(user) { user.admin? ? all : where(owner: Owner.managed_by(user)) }
  scope :visible_to, ->(user) {
    manageable_by(user).or(where(visibility: "group", visibility_group: user.groups)).or(where(visibility: "public"))
  }

  # Latest scan per artifact on the default branches (ADR 0008).
  def self.current_counts(projects)
    default_branches = Repo.where(project_id: projects.select(:id)).select(:default_branch_id)
    latest_scans = Scan.current(default_branches).joins(branch: :repo).select("repos.project_id", "scans.counts")

    latest_scans.each_with_object({}) do |scan, totals|
      project_totals = totals[scan.project_id] ||= {}
      scan.counts.each do |finding_type, severities|
        type_totals = project_totals[finding_type] ||= {}
        severities.each { |severity, count| type_totals[severity] = type_totals.fetch(severity, 0) + count }
      end
    end
  end

  before_validation { self.visibility_group = nil if owner&.user? && !visible_to_group? }

  validate :user_visibility_requires_user_owner
  validate :visibility_group_allowed

  private
    def user_visibility_requires_user_owner
      return unless visible_to_user? && owner && !owner.user?

      errors.add(:visibility, "user is only allowed for projects owned by a user")
    end

    def visibility_group_allowed
      return unless owner

      if !owner.user?
        errors.add(:visibility_group, "must be empty for projects owned by a group") if visibility_group.present?
      elsif visible_to_group? && visibility_group.blank?
        errors.add(:visibility_group, "can't be blank")
      elsif will_save_change_to_visibility_group? && visibility_group.present? && !owner.user.groups.include?(visibility_group)
        errors.add(:visibility_group, "must be one of the owner's current groups")
      end
    end
end
