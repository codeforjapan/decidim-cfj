# frozen_string_literal: true

namespace :cityos_omniauth do
  desc "Validate effective CityOS OmniAuth settings without printing their values"
  task preflight: :environment do
    failures = []
    enabled_count = 0

    Decidim::Organization.find_each do |organization|
      provider_config = Decidim::Cfj::CityosOmniauthConfiguration.provider_config(organization)
      next unless provider_config

      enabled_count += 1
      missing_keys = Decidim::Cfj::CityosOmniauthConfiguration.missing_keys(provider_config)
      failures << [organization.id, missing_keys] if missing_keys.any?
    rescue StandardError
      failures << [organization.id, [:configuration_unreadable]]
    end

    if failures.any?
      failures.each do |organization_id, missing_keys|
        message = "CityOS configuration invalid: " \
                  "organization_id=#{organization_id} missing=#{missing_keys.join(",")}"
        warn message
      end
      abort "CityOS OmniAuth preflight failed for #{failures.size} organization(s)"
    end

    puts "CityOS OmniAuth preflight passed: enabled_organizations=#{enabled_count}"
  end
end
