class ReposController < ApplicationController
  def show
    @repo = Repo.visible_to(Current.user).find(params[:id])
  end

  def update
    repo = manageable_repo
    repo.update!(default_branch: repo.branches.find(params.expect(repo: [ :default_branch_id ])[:default_branch_id]),
      default_branch_manual: true)
    redirect_to edit_project_path(repo.project), notice: "Default branch updated."
  end

  def destroy
    repo = manageable_repo
    return redirect_to(edit_project_path(repo.project), alert: "Type the repo name to confirm.") unless confirmed?(repo.name)

    Purge.new(repo).call
    redirect_to edit_project_path(repo.project), notice: "Repo #{repo.name} deleted."
  end

  private
    def manageable_repo
      Repo.where(project: manageable_projects).find(params[:id])
    end
end
