class BranchesController < ApplicationController
  def show
    branch = Branch.visible_to(Current.user).find(params[:id])
    redirect_to repo_path(branch.repo, branch: branch.name), status: :moved_permanently
  end

  def destroy
    branch = Branch.where(repo: Repo.where(project: manageable_projects)).find(params[:id])
    project = branch.repo.project
    return redirect_to(edit_project_path(project), alert: "Type the branch name to confirm.") unless confirmed?(branch.name)

    Purge.new(branch).call
    redirect_to edit_project_path(project), notice: "Branch #{branch.name} deleted."
  end
end
