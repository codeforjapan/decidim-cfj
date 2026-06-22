# frozen_string_literal: true

# HTML-escape the organization name at the helper level.
Rails.application.config.to_prepare do
  Decidim::OrganizationHelper # rubocop:disable Lint/Void

  module DecidimOrganizationHelperEscapeNamePatch
    def organization_name(organization = current_organization)
      ERB::Util.html_escape(super)
    end
  end

  Decidim::OrganizationHelper.prepend(DecidimOrganizationHelperEscapeNamePatch)
end
