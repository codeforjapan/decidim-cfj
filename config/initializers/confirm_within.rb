# frozen_string_literal: true

# Confirmation links, both for signing up and for changing the email, expire after
# DECIDIM_CONFIRM_WITHIN_DAYS days (default 1). 0 keeps them valid forever, as Decidim does by default.
#
# Without a limit, a pending email change can be confirmed months later, for example after
# the account has been given admin rights.
confirm_within_days = Integer(Decidim::Env.new("DECIDIM_CONFIRM_WITHIN_DAYS", "1").value, 10, exception: false) || 1
Devise.confirm_within = confirm_within_days.positive? ? confirm_within_days.days : nil

Rails.application.config.to_prepare do
  Decidim::User

  # The resend form at /users/confirmation/new does not require signing in, and Devise
  # issues a fresh link there once the old one has expired. For a pending email change
  # that would bring the expired change back, so only the signed-in resend on the
  # account page may do it.
  module DecidimUserExpiredReconfirmationPatch
    def resend_confirmation_instructions
      return false if pending_reconfirmation? && confirmation_period_expired?

      super
    end
  end

  Decidim::User.prepend(DecidimUserExpiredReconfirmationPatch)
end
