class ProjectsController < ApplicationController
  def index
  end

  def show
    @project = Project.visible_to(Current.user).find(params[:id])
  end
end
