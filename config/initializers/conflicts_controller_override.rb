# frozen_string_literal: true

# Scopes the conflict looked up by edit/update to the current organization,
# matching the scope already applied to #collection.
Rails.application.config.to_prepare do
  Decidim::Admin::ConflictsController # rubocop:disable Lint/Void

  module DecidimAdminConflictsOrganizationScopePatch
    def self.prepended(base)
      base.before_action :ensure_conflict_in_current_organization, only: [:edit, :update]
    end

    private

    def ensure_conflict_in_current_organization
      return if Decidim::Verifications::Conflict
                .joins(:current_user)
                .where(decidim_users: { decidim_organization_id: current_organization.id })
                .exists?(id: params[:id])

      raise ActionController::RoutingError, "Not Found"
    end
  end

  Decidim::Admin::ConflictsController.prepend(DecidimAdminConflictsOrganizationScopePatch)
end
