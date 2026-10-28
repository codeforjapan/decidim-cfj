# frozen_string_literal: true

# Resolves the `included_in` resource only among visible component resources
# of the current organization. Anything else resolves to nil and the linked
# resource announcement is not shown.
Rails.application.config.to_prepare do
  module DecidimLinkedResourceOrganizationScopePatch
    private

    def linked_resource
      return @linked_resource if defined?(@linked_resource)

      @linked_resource = organization_linked_resource
    end

    def organization_linked_resource
      resource = GlobalID::Locator.locate(params[:included_in].to_s, only: [Decidim::HasComponent, Decidim::Budgets::Project])
      resource if resource && resource.organization == current_organization && resource.visible?
    rescue NameError, ArgumentError, ActiveRecord::RecordNotFound
      nil
    end
  end

  Decidim::ApplicationController.prepend(DecidimLinkedResourceOrganizationScopePatch)
end
