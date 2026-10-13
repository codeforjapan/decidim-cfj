# frozen_string_literal: true

# Binds a signed-in user to the organization of the requested host.
#
# The session store is shared by every organization and Devise restores the
# user by id alone, so a session cookie issued on one organization's host is
# also accepted on another organization's host (see GHSA-r3v7-5x4c-c69q for the
# API side of the same problem). Sign out any user that does not belong to the
# current organization, whichever way they were authenticated: session,
# password, remember-me cookie or OmniAuth.
#
# Decidim::Middleware::CurrentOrganization runs before Warden, so the
# organization is already resolved here. System admins use the :admin scope
# and are not affected.
Warden::Manager.after_set_user scope: :user do |user, auth, _opts|
  organization = auth.env["decidim.current_organization"]
  next if organization && user.decidim_organization_id == organization.id

  auth.logout(:user)
end
