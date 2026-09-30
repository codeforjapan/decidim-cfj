# frozen_string_literal: true

# Scopes the conflict looked up by edit/update to the current organization,
# matching the scope already applied to #collection.
Rails.application.config.to_prepare do
  Decidim::Admin::ConflictsController

  module DecidimAdminConflictsOrganizationScopePatch
    def self.prepended(base)
      base.before_action :ensure_conflict_in_current_organization, only: [:edit, :update]
    end

    private

    def ensure_conflict_in_current_organization
      conflict = Decidim::Verifications::Conflict.find_by(id: params[:id])
      return if conflict.present? &&
                conflict.current_user&.decidim_organization_id == current_organization.id &&
                conflict.managed_user&.decidim_organization_id == current_organization.id

      raise ActionController::RoutingError, "Not Found"
    end
  end

  Decidim::Admin::ConflictsController.prepend(DecidimAdminConflictsOrganizationScopePatch)
end
