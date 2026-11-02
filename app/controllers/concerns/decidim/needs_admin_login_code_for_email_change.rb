# frozen_string_literal: true

module Decidim
  # Requires the admin login code before a user who may enter the admin panel changes their
  # email. Otherwise someone with only the password could move the email to their own address
  # and receive the admin login codes there.
  module NeedsAdminLoginCodeForEmailChange
    extend ActiveSupport::Concern
    include Decidim::AdminLoginCodeSession
    include Decidim::UserRoleChecker

    included do
      prepend_before_action :require_admin_login_code_for_email_change
    end

    private

    def require_admin_login_code_for_email_change
      return unless action_name == "update"
      return unless Decidim::AdminLoginCode.enabled?
      return unless current_user
      return unless email_change_requested?
      return unless may_enter_admin_panel?(current_user)
      return if admin_login_code_verified?

      flash[:alert] = t("decidim.admin_login_codes.email_change.required")
      redirect_to_admin_login_code(return_to: decidim.account_path)
    end

    def email_change_requested?
      email = params.dig(:user, :email).to_s.strip
      email.present? && email.downcase != current_user.email.downcase
    end

    # Outside admin paths decidim_awesome does not treat scoped admins as admins, so this
    # also looks at its scoped admins setting, and at users who have already been sent a code.
    def may_enter_admin_panel?(user)
      user.admin? ||
        user_has_any_role?(user, broad_check: true) ||
        awesome_scoped_admin?(user) ||
        Decidim::AdminLoginCode.exists?(user:)
    end

    # Decidim::User.awesome_potential_admins is only filled for admin and space paths,
    # so read the setting itself.
    def awesome_scoped_admin?(user)
      return false unless defined?(Decidim::DecidimAwesome::Config)

      scoped_admins = Decidim::DecidimAwesome::Config.new(user.organization).unfiltered_config[:scoped_admins]
      return false unless scoped_admins.respond_to?(:values)

      scoped_admins.values.flatten.map(&:to_i).include?(user.id)
    end
  end
end
