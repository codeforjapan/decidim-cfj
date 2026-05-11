# frozen_string_literal: true

# Adds the permission check to the recipients_count action
Rails.application.config.to_prepare do
  Decidim::Admin::NewslettersController # rubocop:disable Lint/Void

  module DecidimAdminNewslettersControllerRecipientsCountPatch
    def recipients_count
      enforce_permission_to(:update, :newsletter, newsletter:)
      super
    end
  end

  Decidim::Admin::NewslettersController.prepend(DecidimAdminNewslettersControllerRecipientsCountPatch)
end
