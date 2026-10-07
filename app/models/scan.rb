class Scan < ApplicationRecord
  TRIGGERS = %w[push tag schedule manual pr unknown].freeze

  belongs_to :branch
  belongs_to :artifact
  belongs_to :service_account
  has_many :occurrences, dependent: :delete_all

  scope :visible_to, ->(user) { where(branch: Branch.visible_to(user)) }

  enum :trigger, TRIGGERS.index_by(&:itself), prefix: :triggered_by, validate: true

  # Determined on read so that the order of concurrent uploads does not matter (ADR 0008).
  def predecessor
    branch.scans.where(artifact_id:)
      .where("(scans.created_at, scans.id) < (?, ?)", created_at, id)
      .order(created_at: :desc, id: :desc).first
  end

  def finding_ids
    occurrences.distinct.pluck(:finding_id)
  end
end
