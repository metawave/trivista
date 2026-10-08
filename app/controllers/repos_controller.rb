class ReposController < ApplicationController
  RANGES = { "7" => 7.days, "30" => 30.days, "90" => 90.days, "all" => nil }.freeze
  DEFAULT_RANGE = "90"
  # ponytail: rows are capped and diffs computed per listed scan; paginate or cache when branches get large.
  ROW_LIMIT = 500
  LISTED_SCANS = 10

  def show
    @repo = Repo.visible_to(Current.user).includes(:project).find(params[:id])
    @branches = @repo.branches.order(:name).to_a
    @branch = params[:branch].present? ? @repo.branches.find_by!(name: params[:branch]) : (@repo.default_branch || @branches.first)
    @last_scans = Scan.where(branch: @branches).group(:branch_id).maximum(:created_at)
    return unless @branch

    @current_scans = Scan.current(@branch).includes(:artifact).to_a
    @latest_scan = @branch.scans.order(created_at: :desc, id: :desc).first
    @scan_count = @branch.scans.count
    @finding_type = Finding::TYPES.include?(params[:type]) ? params[:type] : default_finding_type
    params[:view] == "scans" ? load_scans : load_findings
  end

  def update
    repo = manageable_repo
    branch = repo.branches.find(params.expect(repo: [ :default_branch_id ])[:default_branch_id])
    repo.with_lock { repo.update!(default_branch: branch, default_branch_manual: true) }
    redirect_to edit_project_path(repo.project), notice: "Default branch updated."
  end

  def destroy
    repo = manageable_repo
    return redirect_to(edit_project_path(repo.project), alert: "Type the repo name to confirm.") unless confirmed?(repo.name)

    Purge.new(repo).call
    redirect_to edit_project_path(repo.project), notice: "Repo #{repo.name} deleted."
  end

  private
    def load_findings
      @severities = Occurrence::SEVERITIES & params[:severity].to_s.split(",")
      @only_new = params[:only_new] == "1"
      filters = { finding_type: @finding_type, severities: @severities.presence }
      diffs = @current_scans.map { ScanDiff.new(it) }.select(&:predecessor)
      @new_finding_ids = diffs.flat_map(&:new_finding_ids).to_set
      page = ScanFindings.new(@current_scans, finding_ids: (@new_finding_ids.to_a if @only_new)).page(limit: ROW_LIMIT, **filters)
      @rows, @row_count = page.rows, page.total
      load_no_longer_reported(diffs, filters)
    end

    # Per artifact against its predecessor; a finding is listed under the artifacts it disappeared from.
    def load_no_longer_reported(diffs, filters)
      @gone_by_scan = diffs.to_h { [ it.predecessor.id, it.no_longer_reported_finding_ids.to_set ] }
      gone_ids = @gone_by_scan.values.reduce(Set.new, :|)
      @gone_total = gone_ids.size
      @predecessors = diffs.map(&:predecessor).index_by(&:id)
      @no_longer_reported = gone_ids.any? ? ScanFindings.new(@predecessors.values, finding_ids: gone_ids.to_a).page(limit: ROW_LIMIT, **filters).rows : []
    end

    def load_scans
      @range = RANGES.key?(params[:range]) ? params[:range] : DEFAULT_RANGE
      @series = Trend.new(@branch, finding_type: @finding_type, since: RANGES[@range]&.ago).series
      listed_ids = @series.flat_map { it.points.last(LISTED_SCANS).map(&:scan_id) }
      @diffs = Scan.where(id: listed_ids).to_h { [ it.id, ScanDiff.new(it) ] }
    end

    def current_counts
      @current_counts ||= Scan.sum_counts(@current_scans)
    end
    helper_method :current_counts

    def default_finding_type
      Finding::TYPES.find { current_counts[it].values.sum.positive? } || Finding::TYPES.first
    end

    def manageable_repo
      Repo.where(project: manageable_projects).find(params[:id])
    end
end
