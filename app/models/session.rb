# A signed-in browser; the cookie only carries its id, so signing out or ending it here ends it for good (ADR 0006).
class Session < ApplicationRecord
  belongs_to :user

  scope :expired, -> {
    config = Rails.configuration.x
    where(created_at: ...config.session_max_age.ago).or(where(updated_at: ...config.session_idle_timeout.ago))
  }

  def expired?
    created_at < Rails.configuration.x.session_max_age.ago || updated_at < Rails.configuration.x.session_idle_timeout.ago
  end
end
