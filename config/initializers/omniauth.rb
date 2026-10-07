Rails.application.config.middleware.use OmniAuth::Builder do
  provider :openid_connect,
    issuer: ENV["OIDC_ISSUER"],
    discovery: true,
    response_type: :code,
    pkce: true,
    scope: %i[openid profile email groups],
    client_options: {
      identifier: ENV["OIDC_CLIENT_ID"],
      secret: ENV["OIDC_CLIENT_SECRET"],
      redirect_uri: ENV["OIDC_REDIRECT_URI"]
    }
end

OmniAuth.config.allowed_request_methods = %i[post]
OmniAuth.config.logger = Rails.logger
