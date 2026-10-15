module Admin
  class UsersController < ApplicationController
    before_action { raise ActiveRecord::RecordNotFound unless Current.user.admin? }

    def index
      @users = User.includes(:sessions).order(:name, :sub)
    end

    def deactivate
      user = User.find(params[:id])
      raise User::NotDeactivatable, "you cannot deactivate yourself" if user == Current.user

      user.deactivate!
      Rails.event.notify("trivista.user_deactivated", target_user_id: user.id)
      redirect_to admin_users_path, notice: "User deactivated, all tokens revoked."
    rescue User::NotDeactivatable => error
      @users = User.includes(:sessions).order(:name, :sub)
      flash.now[:alert] = error.message
      render :index, status: :unprocessable_content
    end

    def end_sessions
      User.find(params[:id]).sessions.delete_all
      Rails.event.notify("trivista.sessions_ended", target_user_id: params[:id].to_i)
      redirect_to admin_users_path, notice: "Sessions ended."
    end

    def reactivate
      User.find(params[:id]).reactivate!
      Rails.event.notify("trivista.user_reactivated", target_user_id: params[:id].to_i)
      redirect_to admin_users_path, notice: "User reactivated. Tokens stay revoked."
    end
  end
end
