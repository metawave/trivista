# Applies the login rules of ADR 0006 to verified OIDC claims.
class Login
  class Rejected < StandardError; end

  OVERAGE_MARKERS = %w[_claim_names hasgroups].freeze

  def initialize(claims)
    @claims = claims
  end

  def user!
    raise Rejected, "sign-in at the identity provider is too old" unless recently_authenticated?

    user = User.find_or_initialize_by(iss: issuer, sub: subject)
    return admit_break_glass(user) if user.break_glass?

    groups = groups!
    unless groups.include?(oidc.login_group)
      user.deactivate! if user.persisted? && !user.deactivated?
      raise Rejected, "not a member of the login group"
    end
    raise Rejected, "user is deactivated" if user.deactivated?

    user.with_lock do
      user.revoke_tokens_created_for_groups!(user.groups - groups) if user.persisted?
      user.update!(name:, groups:, admin: groups.include?(oidc.admin_group))
    end
    user
  end

  private
    attr_reader :claims

    def admit_break_glass(user)
      user.update!(name:, groups: Array(claims[oidc.groups_claim]), admin: true, deactivated_at: nil)
      user
    end

    def groups!
      raise Rejected, "group membership is not available" if OVERAGE_MARKERS.any? { claims.key?(it) }

      groups = claims[oidc.groups_claim]
      raise Rejected, "group membership is not available" unless groups.is_a?(Array) && groups.all?(String)

      groups
    end

    # The identity provider was asked for a sign-in no older than the session maximum (max_age); auth_time proves it.
    def recently_authenticated?
      auth_time = claims["auth_time"]
      auth_time.is_a?(Integer) && Time.zone.at(auth_time) >= Rails.configuration.x.session_max_age.ago - 1.minute
    end

    def issuer
      claims.fetch("iss")
    end

    def subject
      claims.fetch("sub")
    end

    def name
      claims["name"].presence || claims["preferred_username"]
    end

    def oidc
      Rails.configuration.x.oidc
    end
end
