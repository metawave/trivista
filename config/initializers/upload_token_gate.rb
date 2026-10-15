# Rack::MethodOverride parses POST bodies before any controller runs, so the multipart report of an anonymous upload
# would already land in a tempfile; Rails has no hook before that. The gate answers 401 first (ASVS V5.2.1, ADR 0004).
class UploadTokenGate
  PREFIX = "/api/".freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    # Everything below /api is the upload API; checking the prefix also covers variants like /api/scans.json or /api/scans/.
    return @app.call(env) unless env["REQUEST_METHOD"] == "POST" && env["PATH_INFO"].downcase.start_with?(PREFIX)

    secret = env["HTTP_AUTHORIZATION"].to_s[/\ABearer (\S+)\z/, 1]
    return @app.call(env) if secret && UploadToken.usable.exists?(token_digest: UploadToken.digest(secret))

    Rails.event.notify("trivista.upload_rejected", reason: "token", status: 401, ip: Rack::Request.new(env).ip)
    [ 401, { "www-authenticate" => 'Bearer realm="trivista"', "content-type" => "text/plain" }, [ "" ] ]
  end
end

Rails.application.config.middleware.insert_before Rack::MethodOverride, UploadTokenGate
