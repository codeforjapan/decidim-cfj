# frozen_string_literal: true

# Shows a message of our own when signing in with an OmniAuth provider fails,
# instead of the text that comes with the failure.
#
# The error_description of a provider is meant for the client developer
# (RFC 6749, section 4.1.2.1) and can only be written in ASCII. It is already
# written to the log by config/initializers/omniauth_logging.rb.
module DecidimCfjOmniauthFailureMessage
  # Error codes with a message of their own. Any other failure gets the default one.
  REASONS = %w(access_denied).freeze

  protected

  def failure_message
    error_type = request.env["omniauth.error.type"].to_s
    reason = REASONS.include?(error_type) ? error_type : "default"

    I18n.t(reason, scope: "decidim.devise.omniauth_registrations.failure_reasons")
  end
end

# The Devise controller is patched instead of the Decidim one, because since
# Decidim 0.32 the second `devise_for :users` in the decidim-core routes resets
# the omniauth_callbacks controller of the mapping, so Devise handles the
# failure itself. The Decidim controller inherits the patch.
Rails.application.config.to_prepare do
  Devise::OmniauthCallbacksController.prepend(DecidimCfjOmniauthFailureMessage)
end
