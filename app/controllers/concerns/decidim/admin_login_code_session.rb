# frozen_string_literal: true

module Decidim
  # Session state of the admin login code, shared by the controllers that require the code
  # and the code page itself.
  module AdminLoginCodeSession
    extend ActiveSupport::Concern

    # Kept in the warden session of the user scope, so they are discarded on sign out and session timeout.
    VERIFIED_KEY = "cfj_admin_login_code_verified"
    # Set once the user is known to need the code. The code page cannot always check this
    # itself because decidim_awesome scoped admins are only admins on admin paths.
    PENDING_KEY = "cfj_admin_login_code_pending"
    RETURN_TO_KEY = :cfj_admin_login_code_return_to

    private

    # Sends the user to the code page, and back to return_to once the code is entered.
    def redirect_to_admin_login_code(return_to: nil)
      mark_admin_login_code_pending!
      if request.format.html?
        # Overwrite even with nil, so that an older return path is not used for this request.
        session[RETURN_TO_KEY] = return_to
        redirect_to decidim.new_admin_login_code_path
      else
        head :unauthorized
      end
    end

    # Same check as the routes of the admin panel.
    def admin_panel_allowed?
      Decidim::Admin::OrganizationDashboardConstraint.new(request).matches?
    end

    def reject_admin_login_code
      if request.format.html?
        flash[:alert] = t("decidim.core.actions.unauthorized")
        redirect_to decidim.root_path
      else
        head :forbidden
      end
    end

    def admin_login_code_pending?
      warden.session(:user)[PENDING_KEY] == current_user.id
    end

    def mark_admin_login_code_pending!
      warden.session(:user)[PENDING_KEY] = current_user.id
    end

    def admin_login_code_verified?
      warden.session(:user)[VERIFIED_KEY] == current_user.id
    end

    def mark_admin_login_code_verified!
      warden.session(:user)[VERIFIED_KEY] = current_user.id
    end
  end
end
