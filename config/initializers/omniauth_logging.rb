# frozen_string_literal: true

module OmniAuth
  module Logging
    def call_app!(env = @env)
      if env["omniauth.auth"]
        ActiveSupport::Notifications.instrument(
          "omniauth.auth.succeed",
          provider: env["omniauth.auth"]["provider"],
          request_id: env["action_dispatch.request_id"] || env["HTTP_X_REQUEST_ID"]
        )
      end
      super
    end
  end
end

# Add logging for all OmniAuth Strategies
OmniAuth::Strategy.prepend(OmniAuth::Logging)

ActiveSupport::Notifications.subscribe("omniauth.auth.succeed") do |_name, start, finish, _id, payload|
  provider = payload[:provider].to_s.delete("\r\n")[0, 64]
  request_id = payload[:request_id].to_s.delete("\r\n")[0, 128]
  duration_ms = ((finish - start) * 1000).round(1)

  Rails.logger.info "[OmniAuth] result=success provider=#{provider} duration_ms=#{duration_ms} request_id=#{request_id}"
end
