class Project < ApplicationRecord
  belongs_to :owner
  has_many :repos, dependent: :delete_all
  has_many :artifacts, dependent: :delete_all
  has_many :findings, dependent: :delete_all

  enum :visibility, { user: "user", group: "group", public: "public" }, prefix: :visible_to, validate: true

  validate :user_visibility_requires_user_owner

  private
    def user_visibility_requires_user_owner
      return unless visible_to_user? && owner && !owner.user?

      errors.add(:visibility, "user is only allowed for projects owned by a user")
    end
end
