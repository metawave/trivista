# Vulnerabilities in the current scans on the default branches (ADR 0008): highest severity first, then by the
# number of projects reporting them. Findings are per project (ADR 0002), so the identifier joins them across projects.
class TopVulnerabilities
  Row = Data.define(:identifier, :project_count, :severity, :packages, :primary_url)

  def initialize(projects)
    @projects = projects
  end

  def top(limit:)
    current_occurrences.group("findings.identifier")
      .order(Arel.sql("MIN(#{ScanFindings::SEVERITY_RANK}), COUNT(DISTINCT findings.project_id) DESC, findings.identifier"))
      .limit(limit)
      .pluck(Arel.sql("findings.identifier"), Arel.sql("COUNT(DISTINCT findings.project_id)"),
        Arel.sql("MIN(#{ScanFindings::SEVERITY_RANK})"), Arel.sql("array_remove(array_agg(DISTINCT findings.pkg_name), NULL)"),
        Arel.sql("MIN(findings.primary_url)"))
      .map do |identifier, project_count, rank, packages, primary_url|
        Row.new(identifier:, project_count:, severity: Occurrence::SEVERITIES.fetch(rank), packages:, primary_url:)
      end
  end

  private
    attr_reader :projects

    def current_occurrences
      default_branches = Repo.where(project_id: projects.select(:id)).select(:default_branch_id)
      Occurrence.where(scan: Scan.current(default_branches)).joins(:finding).where(findings: { finding_type: "vulnerability" })
    end
end
