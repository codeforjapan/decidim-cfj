# frozen_string_literal: true

def setup_provider_proc(provider, config_mapping = {})
  lambda do |env|
    request = Rack::Request.new(env)
    organization = Decidim::Organization.find_by(host: request.host)
    provider_config = organization.enabled_omniauth_providers[provider]

    config_mapping.each do |option_key, config_key|
      env["omniauth.strategy"].options[option_key] = provider_config[config_key]
    end
  end
end

Rails.application.config.middleware.use OmniAuth::Builder do
  omniauth_config = Rails.application.secrets[:omniauth]

  if omniauth_config && omniauth_config[:line_login].present?
    require "omniauth-line_login"
    provider(
      :line_login,
      setup: setup_provider_proc(:line_login, client_id: :client_id, client_secret: :client_secret)
    )
  end
end
