# frozen_string_literal: true

Rails.application.config.to_prepare do
  Decidim::DecidimAwesome::Admin::ChecksController # rubocop:disable Lint/Void

  # Makes ChecksController#system_login follow link_admin_to_system_admins.
  module DecidimAwesomeSystemLoginSettingPatch
    def system_login
      raise ActionController::RoutingError, "Not Found" unless Decidim::DecidimAwesome.enabled?(:link_admin_to_system_admins)

      super
    end
  end

  Decidim::DecidimAwesome::Admin::ChecksController.prepend(DecidimAwesomeSystemLoginSettingPatch)
end
