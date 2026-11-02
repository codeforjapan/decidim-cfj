# frozen_string_literal: true

module Decidim
  module AdminLoginCodes
    # Issues a new admin login code for a user and emails it.
    class SendCode < Decidim::Command
      # user - The user who enters the admin panel.
      def initialize(user)
        @user = user
      end

      # Broadcasts :ok when the email was sent, :skipped when no code was issued (the admin panel
      # is locked or the resend interval has not passed), and :invalid when the email could not be sent.
      #
      # The email is sent synchronously so that the plain code is not stored in the job queue
      # and does not wait behind other jobs while it is valid.
      def call
        code = Decidim::AdminLoginCode.issue!(user)
        return broadcast(:skipped) if code.nil?
        return broadcast(:invalid) unless deliver(code)

        broadcast(:ok)
      end

      private

      attr_reader :user

      def deliver(code)
        Decidim::AdminLoginCodeMailer.code(user, code).deliver_now
        true
      rescue StandardError => e
        Rails.logger.error("[admin_login_code] could not send a code to user #{user.id}: #{e.class}: #{e.message}")
        # The code never reached the user. sent_at is kept so that the resend interval still
        # limits how often a slow or failing mail server is retried.
        Decidim::AdminLoginCode.where(user:, code_digest: Decidim::AdminLoginCode.digest(user, code))
                               .update_all(code_digest: nil) # rubocop:disable Rails/SkipsModelValidations
        false
      end
    end
  end
end
