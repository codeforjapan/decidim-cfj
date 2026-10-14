# frozen_string_literal: true

# Binds a signed-in user to the organization of the requested host.
#
# The session store is shared by every organization and Devise restores the
# user by id and salt with no organization scope, so a session cookie or a
# remember-me cookie issued on one organization's host is also accepted on
# another organization's host. (The API's JWT authentication in Decidim 0.31
# had the same class of problem, GHSA-r3v7-5x4c-c69q.)
#
# The user is rejected before Warden sets them, not afterwards. A Warden
# after_set_user hook cannot veto: Devise's own hooks (activatable,
# timeoutable, trackable, ...) still receive the record, and activatable
# answers an inactive record with logout, which deletes the key from the
# session shared with the user's own organization. For strategies (remember-me)
# the user is also stored and the session flagged for renewal before any hook
# runs. Returning no user from the session serializer, or failing validation
# in the remember-me strategy, leaves nothing to undo.
#
# Password sign-in (Decidim::User.find_for_authentication) and OmniAuth
# (identities are looked up per organization) are already scoped upstream.
# Email confirmation, invitation acceptance and password reset find the user
# by token alone and then call sign_in. The sign_in override below ends the
# request through Warden's failure app for a user of another organization,
# before Warden is involved and before the action goes on to redirect or
# touch the user as if they were signed in.
#
# Decidim::Middleware::CurrentOrganization runs before Warden::Manager, so the
# organization is already resolved. System admins use the :admin scope and are
# not affected.
require "devise/strategies/rememberable"

module DecidimCfjOrganizationSessionBinding
  def self.member?(user, env)
    organization = env["decidim.current_organization"]
    organization.present? && user.decidim_organization_id == organization.id
  end
end

module DecidimCfjOrganizationBoundSessionSerializer
  # fetch, not user_deserialize: Warden deletes the session key when
  # deserialize returns nil, which would modify the shared session. The key is
  # left untouched and Warden treats the request as having no session user.
  def fetch(scope)
    user = super
    user if user.nil? || scope.to_sym != :user || DecidimCfjOrganizationSessionBinding.member?(user, env)
  end
end

module DecidimCfjOrganizationBoundRememberable
  private

  # Returning false without fail! leaves the strategy neither successful nor
  # halted, so Warden moves on without calling set_user.
  def validate(resource, &)
    return false if scope.to_sym == :user && resource && !DecidimCfjOrganizationSessionBinding.member?(resource, env)

    super
  end
end

module DecidimCfjOrganizationBoundSignIn
  def sign_in(resource_or_scope, *args)
    scope = Devise::Mapping.find_scope!(resource_or_scope)
    resource = args.grep_v(Hash).last || resource_or_scope
    throw :warden, scope: :user if scope == :user && !DecidimCfjOrganizationSessionBinding.member?(resource, request.env)

    super
  end
end

Warden::SessionSerializer.prepend(DecidimCfjOrganizationBoundSessionSerializer)
Devise::Strategies::Rememberable.prepend(DecidimCfjOrganizationBoundRememberable)
Devise::Controllers::SignInOut.prepend(DecidimCfjOrganizationBoundSignIn)
