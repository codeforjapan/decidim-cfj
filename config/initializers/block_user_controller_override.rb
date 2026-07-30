# frozen_string_literal: true

Rails.application.config.to_prepare do
  Decidim::Admin::BlockUserController # rubocop:disable Lint/Void

  module DecidimAdminBlockUserControllerBulkActionsPatch
    def bulk_create
      enforce_permission_to :block, :admin_user
      super
    end

    def bulk_destroy
      enforce_permission_to :block, :admin_user
      super
    end
  end

  Decidim::Admin::BlockUserController.prepend(DecidimAdminBlockUserControllerBulkActionsPatch)
end
