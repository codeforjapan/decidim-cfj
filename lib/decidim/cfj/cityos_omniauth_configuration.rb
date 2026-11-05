# frozen_string_literal: true

module Decidim
  module Cfj
    module CityosOmniauthConfiguration
      PROVIDER = :cityos_dcp_login
      REQUIRED_KEYS = [
        :client_id,
        :client_secret,
        :service_id,
        :policy,
        :scope,
        :opt_api_base_url,
        :authorization_url,
        :optin_url
      ].freeze

      class Error < StandardError; end

      module_function

      def provider_config(organization)
        organization.enabled_omniauth_providers[PROVIDER]
      end

      def missing_keys(provider_config)
        return REQUIRED_KEYS if provider_config.nil?

        REQUIRED_KEYS.select do |key|
          value = provider_config[key]
          value.nil? || value.to_s.strip.empty?
        end
      end
    end
  end
end
