# Deletes the occurrences of scans older than the retention period; the scans and their counts stay for the trends (ADR 0002).
class Retention
  Result = Data.define(:scans, :occurrences) do
    def +(other) = Result.new(scans: scans + other.scans, occurrences: occurrences + other.occurrences)
  end
  NOTHING = Result.new(scans: 0, occurrences: 0)

  def initialize(days: Rails.configuration.x.retention_days)
    @days = days
  end

  def call
    return NOTHING if days.zero?

    expired_scan_ids_by_project.sum(NOTHING) do |project_id, scan_ids|
      removed = prune(Project.find(project_id), scan_ids)
      Result.new(scans: scan_ids.size, occurrences: removed)
    end
  end

  private
    attr_reader :days

    def expired_scan_ids_by_project
      Scan.joins(branch: :repo)
        .where(occurrences_pruned_at: nil, created_at: ...days.days.ago)
        .where.not(id: latest_scans)
        .pluck("repos.project_id", "scans.id")
        .group_by(&:first).transform_values { it.map(&:last) }
    end

    # The newest scan of each branch and artifact keeps its details, however old it is.
    def latest_scans
      Scan.select("DISTINCT ON (scans.branch_id, scans.artifact_id) scans.id")
        .order(Arel.sql("scans.branch_id, scans.artifact_id, scans.created_at DESC, scans.id DESC"))
    end

    # ponytail: one transaction per project; batch the deletes if a project expires millions of occurrences at once.
    def prune(project, scan_ids)
      Scan.transaction do
        owner = project.owner.lock!
        removed = Occurrence.where(scan_id: scan_ids).delete_all
        Scan.where(id: scan_ids).update_all(occurrences_pruned_at: Time.current)
        project.findings.where.missing(:occurrences).delete_all
        owner.update!(occurrence_count: owner.occurrence_count - removed)
        removed
      end
    end
end
