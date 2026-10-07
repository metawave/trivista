# New and no longer reported findings of a scan compared to its predecessor (CONTEXT.md: Diff).
class ScanDiff
  attr_reader :scan, :predecessor

  def initialize(scan)
    @scan = scan
    @predecessor = scan.predecessor
  end

  def new_finding_ids
    current_ids - previous_ids
  end

  def no_longer_reported_finding_ids
    previous_ids - current_ids
  end

  private
    def current_ids
      @current_ids ||= scan.finding_ids
    end

    def previous_ids
      @previous_ids ||= predecessor&.finding_ids || []
    end
end
