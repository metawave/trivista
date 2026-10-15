class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Pages show findings that may point at weak spots; browsers and proxies keep no copy (ASVS V14.3.2).
  before_action :no_store

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
end
