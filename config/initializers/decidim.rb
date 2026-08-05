# frozen_string_literal: true

Decidim.configure do |config|
  # The name of the application
  config.application_name = Decidim::Env.new("DECIDIM_APPLICATION_NAME", "Code for Japan Decidim").to_s

  # The email that will be used as sender in all emails from Decidim
  config.mailer_sender = Decidim::Env.new("DECIDIM_MAILER_SENDER", "info@diycities.jp").to_s

  # Sets the list of available locales for the whole application.
  config.available_locales = [:ja, :en]

  # Sets the default locale for new organizations.
  config.default_locale = Decidim::Env.new("DECIDIM_DEFAULT_LOCALE", "ja").to_s.presence || :ja

  # Map and Geocoder configuration
  if Decidim::Env.new("MAPS_STATIC_PROVIDER", ENV["MAPS_PROVIDER"]).to_s.present?
    static_provider = Decidim::Env.new("MAPS_STATIC_PROVIDER", ENV["MAPS_PROVIDER"]).to_s
    dynamic_provider = Decidim::Env.new("MAPS_DYNAMIC_PROVIDER", ENV["MAPS_PROVIDER"]).to_s
    dynamic_url = ENV["MAPS_DYNAMIC_URL"]
    static_url = ENV["MAPS_STATIC_URL"]
    static_url = "https://image.maps.ls.hereapi.com/mia/1.6/mapview" if static_provider == "here" && static_url.blank?
    config.maps = {
      provider: ENV["MAPS_PROVIDER"],
      api_key: Decidim::Env.new("MAPS_STATIC_API_KEY", ENV["MAPS_API_KEY"]).to_s,
      static: { provider: static_provider, url: static_url },
      dynamic: {
        provider: dynamic_provider,
        api_key: Decidim::Env.new("MAPS_DYNAMIC_API_KEY", ENV["MAPS_API_KEY"]).to_s
      }
    }
    geocoding_host = ENV["MAPS_GEOCODING_HOST"]
    config.maps[:geocoding] = { host: geocoding_host, use_https: true } if geocoding_host
    config.maps[:dynamic][:tile_layer] = {}
    config.maps[:dynamic][:tile_layer][:url] = dynamic_url if dynamic_url
    attribution = ENV["MAPS_ATTRIBUTION"]
    config.maps[:dynamic][:tile_layer][:attribution] = attribution if attribution
    extra_vars = ENV["MAPS_EXTRA_VARS"]
    if extra_vars.present?
      vars = URI.decode_www_form(extra_vars)
      vars.each do |key, value|
        # perform a naive type conversion
        config.maps[:dynamic][:tile_layer][key] = case value
                                                  when /^true$|^false$/i
                                                    value.downcase == "true"
                                                  when /\A[-+]?\d+\z/
                                                    value.to_i
                                                  else
                                                    value
                                                  end
      end
    end
  end

  # Currency unit
  config.currency_unit = "円"

  config.sms_gateway_service = "Decidim::Verifications::Sms::ExampleGateway"

  config.timestamp_service = "Decidim::Initiatives::DummyTimestamp"

  config.pdf_signature_service = "Decidim::Initiatives::PdfSignatureExample"

  # Etherpad configuration
  if Decidim::Env.new("ETHERPAD_SERVER").to_s.present?
    config.etherpad = {
      server: ENV["ETHERPAD_SERVER"],
      api_key: ENV["ETHERPAD_API_KEY"],
      api_version: Decidim::Env.new("ETHERPAD_API_VERSION", "1.2.1").to_s
    }
  end

  # Sets Decidim::Exporters::CSV's default column separator
  config.default_csv_col_sep = ","

  # Machine Translation Configuration
  config.enable_machine_translations = false

  config.machine_translation_service = "Decidim::Dev::DummyTranslator"

  config.content_security_policies_extra = {
    "default-src" => ["*"],
    "img-src" => ["*"],
    "media-src" => ["*"],
    "script-src" => ["*"],
    "style-src" => ["*"],
    "font-src" => ["*"],
    "connect-src" => ["*"]
  }
end

Decidim.config.omniauth_providers = Decidim.omniauth_providers.merge(
  line_login: {
    enabled: Decidim::Env.new("OMNIAUTH_LINE_LOGIN_CHANNEL_ID").present?,
    client_id: Decidim::Env.new("OMNIAUTH_LINE_LOGIN_CHANNEL_ID", nil),
    client_secret: Decidim::Env.new("OMNIAUTH_LINE_LOGIN_CHANNEL_SECRET", nil)
  }
)

Rails.application.config.i18n.available_locales = Decidim.available_locales
Rails.application.config.i18n.default_locale = Decidim.default_locale

# Inform Decidim about the assets folder
Decidim.register_assets_path File.expand_path("app/packs", Rails.application.root)

require "decidim/map/provider/static_map/cfj_osm"

## Set default OGP description length limit. It's used in Decidim::Blogs components
Rails.application.config.default_blog_ogp_description_limit = ENV.fetch("DECIDIM_BLOG_OGP_DESCRIPTION_LIMIT", 150).to_i

# Overwrite Devise.allow_unconfirmed_access_for
Devise.allow_unconfirmed_access_for = Decidim.unconfirmed_access_for

# Set max_complexity of GraphQL::Schema
Rails.application.config.to_prepare do
  Decidim::Api::Schema.max_complexity = 100_000
  if Decidim.config.content_security_policies_extra["frame-src"].blank?
    Decidim.config.content_security_policies_extra["frame-src"] = %w(www.youtube.com docs.google.com www.slideshare.net www.loom.com)
  else
    Decidim.config.content_security_policies_extra["frame-src"].push("www.youtube.com", "docs.google.com", "www.slideshare.net", "www.loom.com")
  end
  if Decidim.config.content_security_policies_extra["script-src"].blank?
    Decidim.config.content_security_policies_extra["script-src"] = %w(js-agent.newrelic.com)
  else
    Decidim.config.content_security_policies_extra["script-src"].push("js-agent.newrelic.com")
  end
end
Decidim.icons.register(name: "line", icon: "line-fill", category: "system", description: "", engine: :core)
Decidim.icons.register(name: "line-fill", icon: "line-fill", category: "system", description: "", engine: :core)

Rails.application.config.to_prepare do
  # make some content_blocks as default
  Decidim.content_blocks.for(:assembly_homepage).find { |block| block.name == :announcement }.default!
  Decidim.content_blocks.for(:participatory_process_homepage).find { |block| block.name == :announcement }.default!
end

## Register LINE as SNS
Decidim.register_social_share_service("LINE") do |service|
  service.icon = "line-fill"
  service.share_uri = "https://social-plugins.line.me/lineit/share?url=%{url}&text=%{title}"
end

## Share buttons on SNS
Decidim.social_share_services = %w(X Facebook LINE)

## Disable Etiquette validator configuration
Decidim.enable_etiquette_validator = false
