class SessionsController < ApplicationController
  allow_unauthenticated_access

  def new
  end

  def create
    user = Login.new(request.env["omniauth.auth"].extra.raw_info.to_hash).user!
    reset_session
    start_new_session_for(user)
    redirect_to root_path
  rescue Login::Rejected => error
    reset_session
    render plain: "Login rejected: #{error.message}", status: :forbidden
  end

  def failure
    render plain: "Login failed", status: :unauthorized
  end

  def destroy
    terminate_session if resume_session
    reset_session
    response.headers["Clear-Site-Data"] = '"cache", "storage"'
    redirect_to login_path
  end
end
