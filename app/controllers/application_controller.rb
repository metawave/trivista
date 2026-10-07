class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :require_login

  helper_method :manageable?

  private
    def manageable?(project)
      Project.manageable_by(Current.user).exists?(project.id)
    end

    def manageable_projects
      Project.manageable_by(Current.user)
    end

    def confirmed?(name)
      params[:confirmation] == name
    end

    def require_login
      Current.user = authenticated_user
      return if Current.user

      reset_session
      redirect_to login_path
    end

    # Sessions end after the maximum age and on deactivation (ADR 0006).
    def authenticated_user
      authenticated_at = session[:authenticated_at]
      return unless session[:user_id] && authenticated_at
      return if Time.zone.at(authenticated_at) < Rails.configuration.x.session_max_age.ago

      User.find_by(id: session[:user_id])&.then { it unless it.deactivated? }
    end
end
