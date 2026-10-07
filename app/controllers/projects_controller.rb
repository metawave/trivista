class ProjectsController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @visibility = Project.visibilities.key?(params[:visibility]) ? params[:visibility] : nil
    @projects = Project.visible_to(Current.user).includes(owner: :user).order(:name, :id)
    @projects = @projects.where("projects.name ILIKE ?", "%#{Project.sanitize_sql_like(@query)}%") if @query.present?
    @projects = @projects.where(visibility: @visibility) if @visibility
    @counts = Project.current_counts(@projects)
    @repo_counts = Repo.where(project_id: @projects.select(:id)).group(:project_id).count
    @last_scans = Scan.joins(branch: :repo).where(repos: { project_id: @projects.select(:id) }).group("repos.project_id").maximum(:created_at)
  end

  def show
    @project = Project.visible_to(Current.user).find(params[:id])
    @repos = @project.repos.includes(:default_branch).order(:name)
    @branch_counts = Branch.where(repo: @repos).group(:repo_id).count
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

  def destroy
    project = manageable_projects.find(params[:id])
    return redirect_to(edit_project_path(project), alert: "Type the project name to confirm.") unless confirmed?(project.name)

    Purge.new(project).call
    redirect_to root_path, notice: "Project #{project.name} deleted."
  end
end
