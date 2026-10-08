module Admin
  class UsersController < ApplicationController
    before_action { raise ActiveRecord::RecordNotFound unless Current.user.admin? }

    def index
      @users = User.order(:name, :sub)
    end

    def deactivate
      user = User.find(params[:id])
      raise User::NotDeactivatable, "you cannot deactivate yourself" if user == Current.user

      user.deactivate!
      redirect_to admin_users_path, notice: "User deactivated, all tokens revoked."
    rescue User::NotDeactivatable => error
      @users = User.order(:name, :sub)
      flash.now[:alert] = error.message
      render :index, status: :unprocessable_content
    end

    def reactivate
      User.find(params[:id]).reactivate!
      redirect_to admin_users_path, notice: "User reactivated. Tokens stay revoked."
    end
  end
end
