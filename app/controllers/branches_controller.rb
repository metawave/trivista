class BranchesController < ApplicationController
  def show
    @branch = Branch.visible_to(Current.user).find(params[:id])
  end
end
