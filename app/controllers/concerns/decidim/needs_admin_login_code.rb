# frozen_string_literal: true

module Decidim
  # Requires signed-in users to enter an emailed code once per session
  # before using the admin panel.
  module NeedsAdminLoginCode
    extend ActiveSupport::Concern
    include Decidim::AdminLoginCodeSession

    included do
      prepend_before_action :require_admin_login_code
    end

    private

    def require_admin_login_code
      return unless Decidim::AdminLoginCode.enabled?
      return unless current_user
      return if admin_login_code_verified?
      return reject_admin_login_code unless admin_panel_allowed?

      redirect_to_admin_login_code(return_to: (request.fullpath if request.get?))
    end
  end
end
