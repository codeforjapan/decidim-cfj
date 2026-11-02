# frozen_string_literal: true

module Decidim
  # Sends and checks the code required by Decidim::NeedsAdminLoginCode.
  class AdminLoginCodesController < Decidim::ApplicationController
    include Decidim::FormFactory
    include Decidim::AdminLoginCodeSession
    # Do not make this page the place to return to after the next sign in.
    skip_before_action :store_current_location

    before_action :require_signed_in_user
    before_action :ensure_enabled
    before_action :redirect_if_verified
    before_action :ensure_pending
    before_action :render_if_locked

    helper_method :masked_email, :login_code

    # Does not send a code: a GET request can be triggered by other sites (an image tag),
    # so the code is only sent from the POST in deliver.
    def new
      @form = form(AdminLoginCodeForm).instance
    end

    def create
      @form = form(AdminLoginCodeForm).from_params(params)

      AdminLoginCodes::VerifyCode.call(@form) do
        on(:ok) do
          mark_admin_login_code_verified!
          redirect_to return_path
        end

        on(:locked) { redirect_to decidim.new_admin_login_code_path }

        on(:invalid) do
          @login_code = nil
          flash.now[:alert] = t(".invalid", attempts: Decidim::AdminLoginCode::MAX_FAILED_ATTEMPTS)
          render :new, status: :unprocessable_entity
        end
      end
    end

    def deliver
      AdminLoginCodes::SendCode.call(current_user) do
        on(:ok) { flash[:notice] = t(".sent") }
        on(:skipped) { flash[:alert] = t(".too_soon") }
        on(:invalid) { flash[:alert] = t("decidim.admin_login_codes.send_code.failed") }
      end
      redirect_to decidim.new_admin_login_code_path
    end

    private

    # authenticate_user! would store this page as the place to return to after sign in,
    # but the pending flag does not survive into the new session.
    def require_signed_in_user
      redirect_to decidim.new_user_session_path unless user_signed_in?
    end

    def ensure_enabled
      redirect_to decidim_admin.root_path unless Decidim::AdminLoginCode.enabled?
    end

    def redirect_if_verified
      redirect_to return_path if admin_login_code_verified?
    end

    # The pending flag is missing when this page is opened in a new session (a restored tab,
    # a remember-me sign in). Check the admin access here then. decidim_awesome scoped admins
    # fail this check outside admin paths and have to open the admin panel again.
    #
    # While impersonating, current_user here is the impersonated user but the admin panel sees
    # the admin, so the code would be emailed to the wrong person.
    def ensure_pending
      return reject_admin_login_code if current_user_impersonated?
      return if admin_login_code_pending?
      return reject_admin_login_code unless admin_panel_allowed?

      mark_admin_login_code_pending!
    end

    def render_if_locked
      render :locked, status: :forbidden if login_code&.locked?
    end

    def login_code
      @login_code ||= Decidim::AdminLoginCode.find_by(user: current_user)
    end

    # The stored path is set by NeedsAdminLoginCode from an admin request.
    def return_path
      session.delete(RETURN_TO_KEY).presence || decidim_admin.root_path
    end

    def masked_email
      local, domain = current_user.email.split("@", 2)
      "#{local[0]}***@#{domain}"
    end
  end
end
