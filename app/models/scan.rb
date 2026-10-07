class Scan < ApplicationRecord
  TRIGGERS = %w[push tag schedule manual pr unknown].freeze

  belongs_to :branch
  belongs_to :artifact
  belongs_to :service_account
  has_many :occurrences, dependent: :delete_all

  scope :visible_to, ->(user) { where(branch: Branch.visible_to(user)) }

  enum :trigger, TRIGGERS.index_by(&:itself), prefix: :triggered_by, validate: true
end
