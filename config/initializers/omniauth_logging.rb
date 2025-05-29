# frozen_string_literal: true

module OmniAuth
  module Logging
    def call_app!(env = @env)
      ActiveSupport::Notifications.instrument("omniauth.auth.succeed", auth: env["omniauth.auth"]) if env["omniauth.auth"]
      super
    end
  end
end

# Add logging for all OmniAuth Strategies
OmniAuth::Strategy.prepend(OmniAuth::Logging)

ActiveSupport::Notifications.subscribe("omniauth.auth.succeed") do |_name, start, finish, _id, payload|
  auth = payload[:auth]
  provider = auth["provider"]
  uid = auth["uid"]
  email = auth.dig("info", "email") || "N/A"

  Rails.logger.info "[OmniAuth] Duration: #{start} - #{finish}, Provider: #{provider}, UID: #{uid}, Email: #{email}, Auth Data: #{auth.inspect}"
end
