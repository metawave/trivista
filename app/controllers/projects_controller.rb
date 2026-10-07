class ProjectsController < ApplicationController
  def index
    @projects = Project.visible_to(Current.user).includes(owner: :user).order(:name, :id)
    @counts = Project.current_counts(@projects)
  end

  def show
    @project = Project.visible_to(Current.user).find(params[:id])
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
