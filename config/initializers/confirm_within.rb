# frozen_string_literal: true

# Confirmation links, both for signing up and for changing the email, expire after
# DECIDIM_CONFIRM_WITHIN_DAYS days (default 1). 0 keeps them valid forever, as Decidim does by default.
#
# Without a limit, a pending email change can be confirmed months later, for example after
# the account has been given admin rights.
confirm_within_days = Rails.application.secrets.dig(:decidim, :confirm_within_days).to_i
Devise.confirm_within = confirm_within_days.positive? ? confirm_within_days.days : nil
