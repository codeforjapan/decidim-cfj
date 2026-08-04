# frozen_string_literal: true

def setup_cityos_dcp_provider_proc(provider, config_mapping = {})
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

  if omniauth_config && omniauth_config[:cityos_dcp_login].present?
    require "omniauth-cityos-dcp"

    provider(
      :cityos_dcp_login,
      cookie_store: Rails.application.config.session_store.to_s.include?("CookieStore"),
      setup: setup_cityos_dcp_provider_proc(
        :cityos_dcp_login,
        client_id: :client_id,
        client_secret: :client_secret,
        service_id: :service_id,
        policy: :policy,
        scope: :scope,
        opt_api_base_url: :opt_api_base_url,
        authorization_url: :authorization_url,
        optin_url: :optin_url
      )
    )
  end
end
