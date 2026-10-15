# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :none
    policy.font_src    :self
    policy.img_src     :self, :data
    policy.object_src  :none
    policy.script_src  :self
    policy.style_src   :self
    policy.connect_src :self
    policy.manifest_src :self
    policy.base_uri :none
    policy.frame_ancestors :none
    # Signing in posts to OmniAuth, which redirects to the identity provider.
    policy.form_action :self, -> { Rails.configuration.x.oidc.issuer }
  end

  # A nonce per request for importmap, inline scripts and inline styles; the session id is still empty on the sign-in page.
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
