Rails.application.configure do
  config.x.upload_rate_limit = Integer(ENV.fetch("UPLOAD_RATE_LIMIT_PER_HOUR", 60))
  config.x.occurrence_quota = Integer(ENV.fetch("OCCURRENCE_QUOTA", 5_000_000))
end
