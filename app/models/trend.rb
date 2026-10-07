# Finding counts over the scans of a branch, one series per artifact (ADR 0008).
class Trend
  Series = Data.define(:artifact, :points)
  Point = Data.define(:scan_id, :uploaded_at, :commit_sha, :tag, :trigger, :counts)

  def initialize(branch, finding_type:, since: nil, trigger: nil)
    @branch = branch
    @finding_type = finding_type
    @since = since
    @trigger = trigger
  end

  def series
    scans.group_by(&:artifact).map do |artifact, artifact_scans|
      Series.new(artifact:, points: artifact_scans.map { point(it) })
    end
  end

  private
    attr_reader :branch, :finding_type, :since, :trigger

    def scans
      scope = branch.scans.includes(:artifact).order(:created_at, :id)
      scope = scope.where(created_at: since..) if since
      scope = scope.where(trigger:) if trigger
      scope
    end

    def point(scan)
      Point.new(scan_id: scan.id, uploaded_at: scan.created_at, commit_sha: scan.commit_sha, tag: scan.tag, trigger: scan.trigger,
        counts: scan.counts.fetch(finding_type, {}))
    end
end
