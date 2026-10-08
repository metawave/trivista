# Daily finding counts of one or more projects: per day the latest scan of each artifact on the default branches,
# without artifacts lacking a scan in the activity window (ADR 0008), summed per severity.
class ProjectTrend
  Point = Data.define(:day, :counts)

  def initialize(projects, finding_type:, since: nil)
    @projects = projects
    @finding_type = finding_type
    @since = since
  end

  def points
    first_day = (since || scans.minimum(:created_at))&.to_date
    return [] unless first_day

    rows = scans.where(created_at: (first_day.beginning_of_day - window)..).order(:created_at, :id)
      .pluck(:branch_id, :artifact_id, :created_at, :counts)
    latest = {}
    (first_day..Time.zone.today).map do |day|
      day_end = day.end_of_day
      while rows.any? && rows.first[2] <= day_end
        branch_id, artifact_id, at, counts = rows.shift
        latest[[ branch_id, artifact_id ]] = [ at, counts ]
      end
      Point.new(day:, counts: sum(latest.values.select { |at, _| at > day_end - window }))
    end
  end

  private
    attr_reader :projects, :finding_type, :since

    def scans
      Scan.joins(branch: :repo).where(repos: { project_id: projects }).where("repos.default_branch_id = scans.branch_id")
    end

    def window
      Rails.configuration.x.artifact_activity_window
    end

    def sum(latest)
      latest.each_with_object(Hash.new(0)) do |(_, counts), totals|
        counts.fetch(finding_type, {}).each { |severity, count| totals[severity] += count }
      end.to_h
    end
end
