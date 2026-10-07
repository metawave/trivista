# Occurrences of a scan grouped per finding, with the highest severity per finding.
class ScanFindings
  Row = Data.define(:finding, :severity, :installed_versions, :locations, :fixed_versions)

  def initialize(scan, finding_ids: nil)
    @scan = scan
    @finding_ids = finding_ids
  end

  def rows(finding_type: nil, severity: nil)
    occurrences = scan.occurrences.includes(:finding)
    occurrences = occurrences.where(finding_id: finding_ids) if finding_ids
    occurrences = occurrences.joins(:finding).where(findings: { finding_type: }) if finding_type

    rows = occurrences.group_by(&:finding).map { |finding, finding_occurrences| row(finding, finding_occurrences) }
    rows = rows.select { it.severity == severity } if severity
    rows.sort_by { [ Occurrence::SEVERITIES.index(it.severity), it.finding.identifier ] }
  end

  private
    attr_reader :scan, :finding_ids

    def row(finding, occurrences)
      Row.new(finding:,
        severity: occurrences.map(&:severity).min_by { Occurrence::SEVERITIES.index(it) },
        installed_versions: occurrences.filter_map(&:installed_version).uniq.sort,
        locations: occurrences.filter_map(&:location).uniq.sort,
        fixed_versions: occurrences.filter_map(&:fixed_version).uniq.sort)
    end
end
