Rails.application.configure do
  config.x.upload_rate_limit = Integer(ENV.fetch("UPLOAD_RATE_LIMIT_PER_HOUR", 60))
  config.x.occurrence_quota = Integer(ENV.fetch("OCCURRENCE_QUOTA", 5_000_000))
  config.x.session_max_age = Integer(ENV.fetch("SESSION_MAX_AGE_HOURS", 8)).hours
  config.x.artifact_activity_window = Integer(ENV.fetch("ARTIFACT_ACTIVITY_DAYS", 30)).days
  config.x.token_max_lifetime = Integer(ENV.fetch("TOKEN_MAX_LIFETIME_DAYS", 365)).days

  config.x.oidc.issuer = ENV["OIDC_ISSUER"]
  config.x.oidc.groups_claim = ENV.fetch("OIDC_GROUPS_CLAIM", "groups")
  config.x.oidc.login_group = ENV["OIDC_LOGIN_GROUP"].presence
  config.x.oidc.admin_group = ENV["OIDC_ADMIN_GROUP"].presence
  config.x.oidc.break_glass_subjects = ENV.fetch("OIDC_BREAK_GLASS_SUBJECTS", "").split(",").map(&:strip).compact_blank

  # A login group is mandatory, otherwise "public" would reach every account of the identity provider (ADR 0006).
  # Asset precompilation in the Docker build runs without runtime configuration.
  config.after_initialize do
    next if Rails.env.test? || ENV["SECRET_KEY_BASE_DUMMY"]

    raise "OIDC_LOGIN_GROUP must be set" if config.x.oidc.login_group.nil?
  end
end
