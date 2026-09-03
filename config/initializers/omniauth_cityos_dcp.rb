# frozen_string_literal: true

require Rails.root.join("lib/decidim/cfj/cityos_omniauth_configuration").to_s

def setup_cityos_dcp_provider_proc(_provider, config_mapping = {})
  lambda do |env|
    request = Rack::Request.new(env)
    organization = Decidim::Organization.find_by(host: request.host)
    raise Decidim::Cfj::CityosOmniauthConfiguration::Error, "cityos_organization_not_found" unless organization

    provider_config = Decidim::Cfj::CityosOmniauthConfiguration.provider_config(organization)
    raise Decidim::Cfj::CityosOmniauthConfiguration::Error, "cityos_provider_disabled" unless provider_config

    missing_keys = Decidim::Cfj::CityosOmniauthConfiguration.missing_keys(provider_config)
    raise Decidim::Cfj::CityosOmniauthConfiguration::Error, "cityos_configuration_missing" if missing_keys.any?

    config_mapping.each do |option_key, config_key|
      env["omniauth.strategy"].options[option_key] = provider_config[config_key]
    end
  end
end

# 0.31 では Rails.application.secrets が廃止されたため、有効・無効の判定を差し替える。
# omniauth-cityos-dcp は 0.31 対応版がまだ無く Gemfile でコメントアウトしているので、
# gem がロードされているかどうかで判定する。Gemfile に gem を戻せばそのまま有効になる。
#
# 有効化する際は、あわせて line_login と同じ形（config/initializers/decidim.rb の
# Decidim.config.omniauth_providers を Decidim::Env で組み立てる）へ移行すること。
# 資格情報そのものは組織ごとの設定から読むため（CityosOmniauthConfiguration#provider_config）、
# ここで必要なのは「プロバイダを登録するかどうか」だけ。
Rails.application.config.middleware.use OmniAuth::Builder do
  if Gem.loaded_specs.key?("omniauth-cityos-dcp")
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
