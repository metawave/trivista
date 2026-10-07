class SessionsController < ApplicationController
  skip_before_action :require_login

  def new
  end

  def create
    user = Login.new(request.env["omniauth.auth"].extra.raw_info.to_hash).user!
    reset_session
    session[:user_id] = user.id
    session[:authenticated_at] = Time.current.to_i
    redirect_to root_path
  rescue Login::Rejected => error
    reset_session
    render plain: "Login rejected: #{error.message}", status: :forbidden
  end

  def failure
    render plain: "Login failed", status: :unauthorized
  end

  def destroy
    reset_session
    redirect_to login_path
  end
end
