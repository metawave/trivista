ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

Rails.configuration.x.oidc.tap do |oidc|
  oidc.issuer = "https://idp.example.com"
  oidc.login_group = "trivista-users"
  oidc.admin_group = "trivista-admins"
  oidc.break_glass_subjects = [ "break-glass-sub" ]
end
OmniAuth.config.test_mode = true

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all
  end
end

class ActionDispatch::IntegrationTest
  def sign_in(sub: "alice-sub", groups: [ "team-a", "trivista-users" ], **raw_info)
    OmniAuth.config.mock_auth[:openid_connect] = OmniAuth::AuthHash.new(
      provider: "openid_connect", uid: sub,
      info: { name: raw_info.fetch("name", sub) },
      extra: { raw_info: { "iss" => "https://idp.example.com", "sub" => sub, "groups" => groups }.merge(raw_info).compact })
    post "/auth/openid_connect"
    follow_redirect!
  end
end
