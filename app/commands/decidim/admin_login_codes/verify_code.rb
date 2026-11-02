# frozen_string_literal: true

module Decidim
  module AdminLoginCodes
    # Checks the code entered by a user against the one emailed to them,
    # and locks the admin panel after too many wrong codes.
    class VerifyCode < Decidim::Command
      delegate :current_user, to: :form

      # form - A Decidim::AdminLoginCodeForm with current_user in its context.
      def initialize(form)
        @form = form
      end

      # Broadcasts :ok when the code matches, :locked when this attempt locked the admin panel,
      # and :invalid otherwise.
      def call
        return broadcast(:invalid) if form.invalid?

        login_code = Decidim::AdminLoginCode.find_by(user: current_user)
        return broadcast(:invalid) if login_code.nil?
        return broadcast(:ok) if login_code.verify(form.code)
        return broadcast(:invalid) unless login_code.lock_if_exhausted!

        notify_lock(login_code.reload.locked_at)
        broadcast(:locked)
      end

      private

      attr_reader :form

      def notify_lock(locked_at)
        Rails.logger.warn("[admin_login_code] locked the admin panel for user #{current_user.id}")
        Decidim::AdminLoginCodeMailer.locked(current_user).deliver_later
        Decidim::System::Admin.find_each do |admin|
          Decidim::AdminLoginCodeMailer.locked_notice(admin, current_user, locked_at).deliver_later
        end
      end
    end
  end
end
