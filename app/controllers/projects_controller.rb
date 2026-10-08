class ProjectsController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @visibility = Project.visibilities.key?(params[:visibility]) ? params[:visibility] : nil
    @projects = Project.visible_to(Current.user).includes(owner: :user).order(:name, :id)
    @projects = @projects.where("projects.name ILIKE ?", "%#{Project.sanitize_sql_like(@query)}%") if @query.present?
    @projects = @projects.where(visibility: @visibility) if @visibility
    @counts = Project.current_counts(@projects)
    @totals = Scan.sum_counts(@counts.values)
    @repo_counts = Repo.where(project_id: @projects.select(:id)).group(:project_id).count
    @last_scans = Scan.joins(branch: :repo).where(repos: { project_id: @projects.select(:id) }).group("repos.project_id").maximum(:created_at)
    load_trend(@projects.select(:id))
    @top_vulnerabilities = TopVulnerabilities.new(@projects).top(limit: TOP_VULNERABILITIES_LIMIT)
  end

  def show
    @project = Project.visible_to(Current.user).find(params[:id])
    @repos = @project.repos.includes(:default_branch).order(:name).to_a
    @current_scans = Scan.current(@repos.filter_map(&:default_branch_id)).includes(:artifact, branch: :repo).to_a
    @current_counts = Scan.sum_counts(@current_scans.map(&:counts))
    @last_scans = Scan.joins(:branch).where(branches: { repo_id: @repos }).group("branches.repo_id").maximum(:created_at)
    @finding_type = Finding::TYPES.include?(params[:type]) ? params[:type] : nil
    @finding_type ? load_findings : load_overview
  end

  def edit
    @project = manageable_projects.find(params[:id])
  end

  def update
    @project = manageable_projects.find(params[:id])
    if @project.update(params.expect(project: [ :visibility, :visibility_group ]))
      redirect_to edit_project_path(@project), notice: "Visibility updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  RANGES = { "7" => 7.days, "30" => 30.days, "90" => 90.days, "all" => nil }.freeze
  DEFAULT_RANGE = "30"
  # ponytail: rows are capped instead of paginated; paginate when projects regularly exceed the cap.
  ROW_LIMIT = 500
  TOP_VULNERABILITIES_LIMIT = 6

  def destroy
    project = manageable_projects.find(params[:id])
    return redirect_to(edit_project_path(project), alert: "Type the project name to confirm.") unless confirmed?(project.name)

    Purge.new(project).call
    redirect_to root_path, notice: "Project #{project.name} deleted."
  end

  private
    def load_trend(projects)
      @range = RANGES.key?(params[:range]) ? params[:range] : DEFAULT_RANGE
      @trend_type = Finding::TYPES.include?(params[:trend]) ? params[:trend] : Finding::TYPES.first
      @trend = ProjectTrend.new(projects, finding_type: @trend_type, since: RANGES[@range]&.ago).points
    end

    def load_overview
      load_trend(@project)
      @repo_counts = @current_scans.group_by { it.branch.repo_id }.transform_values { Scan.sum_counts(it.map(&:counts)) }
    end

    def load_findings
      @severities = Occurrence::SEVERITIES & params[:severity].to_s.split(",")
      page = ScanFindings.new(@current_scans).page(limit: ROW_LIMIT, finding_type: @finding_type, severities: @severities.presence)
      @rows, @row_count = page.rows, page.total
    end
end
