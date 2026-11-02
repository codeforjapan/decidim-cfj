# frozen_string_literal: true

require "shellwords"

module Decidim
  # Delivers the code required to enter the admin panel, and the notices sent when it gets locked.
  class AdminLoginCodeMailer < ApplicationMailer
    def code(user, code)
      with_user(user) do
        @user = user
        @organization = user.organization
        @code = code
        @expires_in = Decidim::AdminLoginCode::EXPIRES_IN.in_minutes.to_i
        subject = I18n.t("decidim.admin_login_code_mailer.code.subject", organization_name: organization_name(@organization))

        mail(to: user.email, subject:)
      end
    end

    # To the user whose admin panel was locked.
    def locked(user)
      with_user(user) do
        @user = user
        @organization = user.organization
        subject = I18n.t("decidim.admin_login_code_mailer.locked.subject", organization_name: organization_name(@organization))

        mail(to: user.email, subject:)
      end
    end

    # To a system admin, who can unlock it.
    def locked_notice(admin, user, locked_at)
      @user = user
      @organization = user.organization
      @locked_at = locked_at
      I18n.with_locale(@organization.default_locale) do
        subject = I18n.t("decidim.admin_login_code_mailer.locked_notice.subject", organization_name: organization_name(@organization))

        mail(to: admin.email, subject:)
      end
    end
  end
end
