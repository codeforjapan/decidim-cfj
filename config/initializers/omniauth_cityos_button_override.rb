# frozen_string_literal: true

# CityOS allows icons to be optional and requires the `config[:label]` to be visible
#
# cf. decidim-core/app/views/decidim/devise/shared/_omniauth_buttons.html.erb, decidim-core/app/helpers/decidim/omniauth_helper.rb
Rails.application.config.to_prepare do
  Decidim::OmniauthHelper # rubocop:disable Lint/Void

  module CityosOmniauthButtonPatch
    def oauth_icon(provider)
      return super unless provider.to_sym == Decidim::Cfj::CityosOmniauthConfiguration::PROVIDER

      config = current_organization.enabled_omniauth_providers[provider.to_sym] || {}
      icon_path = config[:icon_path].presence

      parts = []
      parts << external_icon(icon_path) if icon_path
      parts << tag.span(config[:label].presence || provider_name(provider))

      safe_join(parts)
    end
  end

  Decidim::OmniauthHelper.prepend(CityosOmniauthButtonPatch)
end
