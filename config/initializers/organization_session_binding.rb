# frozen_string_literal: true

# Binds a signed-in user to the organization of the requested host.
#
# The session store is shared by every organization and Devise restores the
# user by id alone, so a session cookie issued on one organization's host is
# also accepted on another organization's host (see GHSA-r3v7-5x4c-c69q for the
# API side of the same problem). Treat any user that does not belong to the
# current organization as signed out, whichever way they were authenticated:
# session, password, remember-me cookie or OmniAuth.
#
# Only the current request is affected. Signing out through Warden#logout would
# run Devise's forgetable hook (expiring the user's remember-me on every
# device) and, with the shared cache store, drop the session the user still
# has on their own organization.
#
# The hook is unshifted so that it runs before Devise's own after_set_user
# hooks (trackable, rememberable, ...), which then see the user as signed out.
#
# Decidim::Middleware::CurrentOrganization runs before Warden, so the
# organization is already resolved here. System admins use the :admin scope
# and are not affected.
Warden::Manager.after_set_user({ scope: :user }, :unshift) do |user, auth, _opts|
  organization = auth.env["decidim.current_organization"]
  next if organization && user.decidim_organization_id == organization.id

  auth.set_user(nil, scope: :user, store: false, run_callbacks: false)
end
