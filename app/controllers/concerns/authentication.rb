# Session handling from `bin/rails generate authentication`, signing in through OIDC instead of passwords (ADR 0006).
module Authentication
  extend ActiveSupport::Concern

  SESSION_COOKIE = Rails.env.production? ? :"__Host-session_id" : :session_id

  included do
    before_action :require_authentication
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    # Sessions end after the maximum age and after inactivity; activity is recorded at most once a minute.
    def find_session_by_cookie
      session = Session.find_by(id: cookies.signed[SESSION_COOKIE]) if cookies.signed[SESSION_COOKIE]
      return unless session
      return session.destroy && nil if session.expired?

      session.touch if session.updated_at < 1.minute.ago
      session
    end

    def request_authentication
      cookies.delete(SESSION_COOKIE)
      redirect_to login_path
    end

    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[SESSION_COOKIE] = { value: session.id, httponly: true, same_site: :lax, secure: Rails.env.production? }
      end
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(SESSION_COOKIE)
    end
end
