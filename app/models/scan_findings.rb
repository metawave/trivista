# Occurrences of a scan grouped per finding, with the highest severity per finding.
# Aggregates and limits in the database, so large scans do not load every occurrence.
class ScanFindings
  Row = Data.define(:finding, :severity, :installed_versions, :locations, :fixed_versions)
  Page = Data.define(:rows, :total)

  # Ranks follow the order of Occurrence::SEVERITIES.
  SEVERITY_RANK = "CASE occurrences.severity WHEN 'CRITICAL' THEN 0 WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 " \
    "WHEN 'LOW' THEN 3 WHEN 'UNKNOWN' THEN 4 END"

  def initialize(scan, finding_ids: nil)
    @scan = scan
    @finding_ids = finding_ids
  end

  def page(limit:, finding_type: nil, severities: nil)
    aggregated = aggregate(finding_type, severities)
    total = Occurrence.connection.select_value("SELECT COUNT(*) FROM (#{aggregated.to_sql}) AS finding_groups")
    records = aggregated.order(Arel.sql("severity_rank, findings.identifier, occurrences.finding_id")).limit(limit).to_a
    findings = Finding.where(id: records.map(&:finding_id)).index_by(&:id)

    Page.new(total:, rows: records.map { row(findings.fetch(it.finding_id), it) })
  end

  private
    attr_reader :scan, :finding_ids

    def aggregate(finding_type, severities)
      scope = scan.occurrences.joins(:finding)
      scope = scope.where(finding_id: finding_ids) if finding_ids
      scope = scope.where(findings: { finding_type: }) if finding_type
      scope = scope.group("occurrences.finding_id", "findings.identifier").select(
        "occurrences.finding_id",
        "MIN(#{SEVERITY_RANK}) AS severity_rank",
        "array_remove(array_agg(DISTINCT occurrences.installed_version), NULL) AS installed_versions",
        "array_remove(array_agg(DISTINCT occurrences.location), NULL) AS locations",
        "array_remove(array_agg(DISTINCT occurrences.fixed_version), NULL) AS fixed_versions")
      severities ? scope.having("MIN(#{SEVERITY_RANK}) IN (?)", severities.map { Occurrence::SEVERITIES.index(it) }) : scope
    end

    def row(finding, record)
      Row.new(finding:, severity: Occurrence::SEVERITIES.fetch(record.severity_rank),
        installed_versions: record.installed_versions, locations: record.locations, fixed_versions: record.fixed_versions)
    end
end
