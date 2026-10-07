class ReposController < ApplicationController
  def show
    @repo = Repo.visible_to(Current.user).find(params[:id])
  end
end
