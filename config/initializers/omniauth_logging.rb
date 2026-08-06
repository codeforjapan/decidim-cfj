# frozen_string_literal: true

OmniAuth.config.logger = Rails.logger

module OmniAuth
  module CfjAuditLogging
    def call_app!(env = @env)
      # for logging only once
      if (auth = env["omniauth.auth"]) && !env["cfj.omniauth.logged"]
        env["cfj.omniauth.logged"] = true
        Rails.logger.info(
          "[omniauth] phase=callback result=ok " \
          "provider=#{auth["provider"]} uid=#{auth["uid"]} " \
          "email_from_idp=#{auth.dig("info", "email").present?} " \
          "request_id=#{env["action_dispatch.request_id"]}"
        )
      end
      super
    end
  end
end

OmniAuth::Strategy.prepend(OmniAuth::CfjAuditLogging)

# Logging on failure in OmniAuth
#
# This uses env["omniauth.error.type"].
#
module CfjOmniauthFailureLogging
  class << self
    def install!
      return if @installed

      devise_on_failure = OmniAuth.config.on_failure
      OmniAuth.config.on_failure = lambda do |env|
        log(env)
        devise_on_failure.call(env)
      end
      @installed = true
    end

    def log(env)
      error = env["omniauth.error"]
      Rails.logger.warn(
        "[omniauth] phase=callback result=failure " \
        "provider=#{env["omniauth.error.strategy"]&.name} " \
        "type=#{env["omniauth.error.type"]} " \
        "error=#{error&.class} " \
        "message=#{error.respond_to?(:message) ? error.message.to_s.truncate(200).inspect : "nil"} " \
        "request_id=#{env["action_dispatch.request_id"]}"
      )
    end
  end
end

# Logging on failure in Decidim
module DecidimOmniauthRegistrationAuditLog
  def create
    super
  ensure
    log_cfj_omniauth_registration_result
  end

  private

  def log_cfj_omniauth_registration_result
    result =
      if user_signed_in?
        "ok"
      elsif @form.respond_to?(:errors) && @form.errors.any?
        "invalid"
      else
        # already registered, but not signed in
        "pending"
      end

    # full_messages is too verbose, so use attribute names only
    error_keys = (@form.errors.attribute_names.join(",") if @form.respond_to?(:errors))

    Rails.logger.public_send(result == "ok" ? :info : :warn,
                             "[omniauth] phase=registration result=#{result} " \
                             "provider=#{@form.try(:provider)} uid=#{@form.try(:uid)} " \
                             "errors=#{error_keys.presence || "-"} " \
                             "request_id=#{request.request_id}")
  end
end

Rails.application.config.to_prepare do
  CfjOmniauthFailureLogging.install!
  Decidim::Devise::OmniauthRegistrationsController.prepend(DecidimOmniauthRegistrationAuditLog)
end
