# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CityOS OmniAuth integration" do
  it "registers the CityOS authorization and callback routes" do
    routes = Decidim::Core::Engine.routes.url_helpers

    expect(routes).to respond_to(:user_cityos_dcp_login_omniauth_authorize_path)
    expect(routes).to respond_to(:user_cityos_dcp_login_omniauth_callback_path)
  end

  it "uses Decidim's standard icon path labels" do
    key = "decidim.system.organizations.omniauth_settings.icon_path"

    expect(I18n.t(key, locale: :ja)).to eq("アイコンのパス")
    expect(I18n.t(key, locale: :en)).to eq("Icon path")
  end

  it "does not require a CityOS icon by default" do
    expect(Rails.application.secrets.dig(:omniauth, :cityos_dcp_login, :icon_path)).to be_nil
  end

  it "keeps the legacy client credential environment names as fallbacks" do
    secrets = Rails.root.join("config/secrets.yml").read

    expect(secrets).to include("OMNIAUTH_CITYOS_DCP_LOGIN_CLIENT_ID")
    expect(secrets).to include("OMNIAUTH_CITYOS_DCP_LOGIN_CLIENT_SECRET")
  end

  it "reports missing required settings without exposing their values" do
    configuration = Decidim::Cfj::CityosOmniauthConfiguration
    provider_config = configuration::REQUIRED_KEYS.index_with { |key| "value-for-#{key}" }
    provider_config[:client_secret] = ""

    expect(configuration.missing_keys(provider_config)).to eq([:client_secret])
  end

  it "rejects an unknown host with a stable failure code" do
    env = Rack::MockRequest.env_for("/users/auth/cityos_dcp_login", "HTTP_HOST" => "unknown.example")
    env["omniauth.strategy"] = double(options: {})
    allow(Decidim::Organization).to receive(:find_by).and_return(nil)

    setup = setup_cityos_dcp_provider_proc(:cityos_dcp_login, client_id: :client_id)

    expect { setup.call(env) }.to raise_error(
      Decidim::Cfj::CityosOmniauthConfiguration::Error,
      "cityos_organization_not_found"
    )
  end
end
