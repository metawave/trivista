# omniauth_openid_connect prefers a code_verifier or nonce sent with the callback over the ones it keeps in the
# session; a callback that brings its own is never legitimate (ASVS V10.1.2).
class OidcCallbackGuard
  # Covers the callback and its variants (trailing slash, case) that OmniAuth also treats as callback.
  PREFIX = "/auth/".freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    return [ 400, { "content-type" => "text/plain" }, [ "Bad request" ] ] if request.path.downcase.start_with?(PREFIX) && (request.params.keys & %w[code_verifier nonce]).any?

    @app.call(env)
  end
end

OIDC_OPTIONS = {
  issuer: ENV["OIDC_ISSUER"],
  discovery: true,
  response_type: :code,
  pkce: true,
  client_signing_alg: :RS256,
  # Asks the identity provider for a sign-in at most this old instead of silently reusing a longer IdP session;
  # the gem has a max_age option but does not send it. Login checks auth_time against the same limit (ADR 0006).
  extra_authorize_params: { max_age: Integer(ENV.fetch("SESSION_MAX_AGE_HOURS", 8)) * 3600 },
  scope: %i[openid profile groups],
  client_options: {
    identifier: ENV["OIDC_CLIENT_ID"],
    secret: ENV["OIDC_CLIENT_SECRET"],
    redirect_uri: ENV["OIDC_REDIRECT_URI"]
  }
}.freeze

Rails.application.config.middleware.use OidcCallbackGuard
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :openid_connect, **OIDC_OPTIONS
end

OmniAuth.config.allowed_request_methods = %i[post]
OmniAuth.config.logger = Rails.logger
