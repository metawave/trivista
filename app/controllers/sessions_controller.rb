class SessionsController < ApplicationController
  allow_unauthenticated_access

  def new
  end

  def create
    user = Login.new(request.env["omniauth.auth"].extra.raw_info.to_hash).user!
    # A new sign-in replaces the session this browser held, so a copy of the old cookie stops working (ASVS V7.2.4).
    terminate_session if resume_session
    reset_session
    # An admin may deactivate the user between the claims check and here; re-check under the lock deactivation takes.
    user.with_lock do
      raise Login::Rejected, "user is deactivated" if user.deactivated?

      start_new_session_for(user)
    end
    Rails.event.notify("trivista.login", user_id: user.id, admin: user.admin?, ip: request.remote_ip)
    redirect_to root_path
  rescue Login::Rejected => error
    Rails.event.notify("trivista.login_rejected", reason: error.message, ip: request.remote_ip)
    reset_session
    render plain: "Login rejected: #{error.message}", status: :forbidden
  end

  def failure
    Rails.event.notify("trivista.login_failed", ip: request.remote_ip)
    render plain: "Login failed", status: :unauthorized
  end

  def destroy
    if resume_session
      Rails.event.notify("trivista.logout", user_id: Current.user.id)
      terminate_session
    end
    reset_session
    response.headers["Clear-Site-Data"] = '"cache", "storage"'
    redirect_to login_path
  end
end
