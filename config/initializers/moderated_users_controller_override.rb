# frozen_string_literal: true

# Adds the permission check to the bulk_unreport action
Rails.application.config.to_prepare do
  Decidim::Admin::ModeratedUsersController # rubocop:disable Lint/Void

  module DecidimAdminModeratedUsersControllerBulkUnreportPatch
    def bulk_unreport
      enforce_permission_to :unreport, :moderate_users
      super
    end
  end

  Decidim::Admin::ModeratedUsersController.prepend(DecidimAdminModeratedUsersControllerBulkUnreportPatch)
end
