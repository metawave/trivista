# New and no longer reported findings of a scan compared to its predecessor (CONTEXT.md: Diff).
class ScanDiff
  attr_reader :scan, :predecessor

  def initialize(scan)
    @scan = scan
    @predecessor = scan.predecessor
  end

  # Without the details of both scans the difference would show everything as new or gone (ADR 0002).
  def available?
    !scan.occurrences_pruned? && !predecessor&.occurrences_pruned?
  end

  def new_finding_ids
    available? ? current_ids - previous_ids : []
  end

  def no_longer_reported_finding_ids
    available? ? previous_ids - current_ids : []
  end

  private
    def current_ids
      @current_ids ||= scan.finding_ids
    end

    def previous_ids
      @previous_ids ||= predecessor&.finding_ids || []
    end
end
