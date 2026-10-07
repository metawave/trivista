class ProjectsController < ApplicationController
  def index
    @projects = Project.visible_to(Current.user).includes(owner: :user).order(:name, :id)
    @counts = Project.current_counts(@projects)
  end

  def show
    @project = Project.visible_to(Current.user).find(params[:id])
  end
end
