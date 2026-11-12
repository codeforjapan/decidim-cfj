# frozen_string_literal: true

# Redirects the removed Appearance page to the organization settings.
#
# Upstream removed the page and its form in 0.31 (decidim/decidim#14797) but
# left the controller and the route, so the old URL raises NameError
# (decidim/decidim#18093). Remove this file once upstream drops them.
Rails.application.config.to_prepare do
  module DecidimAdminOrganizationAppearanceRedirectPatch
    def edit
      enforce_permission_to :update, :organization, organization: current_organization
      redirect_to decidim_admin.edit_organization_path
    end

    def update
      enforce_permission_to :update, :organization, organization: current_organization
      redirect_to decidim_admin.edit_organization_path
    end
  end

  Decidim::Admin::OrganizationAppearanceController.prepend(DecidimAdminOrganizationAppearanceRedirectPatch)
end
