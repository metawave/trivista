class Scan < ApplicationRecord
  TRIGGERS = %w[push tag schedule manual pr unknown].freeze

  belongs_to :branch
  belongs_to :artifact
  belongs_to :service_account
  has_many :occurrences, dependent: :delete_all

  scope :visible_to, ->(user) { where(branch: Branch.visible_to(user)) }

  enum :trigger, TRIGGERS.index_by(&:itself), prefix: :triggered_by, validate: true

  # Latest scan per branch and artifact, ignoring artifacts without a scan in the activity window (ADR 0008).
  def self.current(branches)
    latest = where(branch: branches, created_at: Rails.configuration.x.artifact_activity_window.ago..)
      .select("DISTINCT ON (scans.branch_id, scans.artifact_id) scans.id")
      .order(Arel.sql("scans.branch_id, scans.artifact_id, scans.created_at DESC, scans.id DESC"))
    where(id: latest)
  end

  # Counts per finding type and severity, summed over the given scans.
  def self.sum_counts(scans)
    scans.each_with_object(Hash.new { |hash, key| hash[key] = Hash.new(0) }) do |scan, totals|
      scan.counts.each { |finding_type, severities| severities.each { |severity, count| totals[finding_type][severity] += count } }
    end
  end

  # Determined on read so that the order of concurrent uploads does not matter (ADR 0008).
  def predecessor
    branch.scans.where(artifact_id:)
      .where("(scans.created_at, scans.id) < (?, ?)", created_at, id)
      .order(created_at: :desc, id: :desc).first
  end

  def occurrences_pruned?
    occurrences_pruned_at.present?
  end

  def finding_ids
    occurrences.distinct.pluck(:finding_id)
  end
end
