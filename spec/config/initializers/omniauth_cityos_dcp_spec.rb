# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CityOS OmniAuth integration" do
  # omniauth-cityos-dcp はまだ 0.31 に対応しておらず Gemfile でコメントアウトしている。
  # gem が無いとプロバイダが登録されないため、それを前提にした例は動かせない。
  # Gemfile に gem を戻すときに、このガードごと外して復活させること。
  #
  # config/secrets.yml も 0.31 では廃止されたので、ここで参照している値は
  # line_login と同じ Decidim::Env 方式へ移す必要がある
  # (config/initializers/omniauth_cityos_dcp.rb のコメントを参照)。
  cityos_gem_available = Gem.loaded_specs.has_key?("omniauth-cityos-dcp")

  it "registers the CityOS authorization and callback routes", skip: !cityos_gem_available do
    routes = Decidim::Core::Engine.routes.url_helpers

    expect(routes).to respond_to(:user_cityos_dcp_login_omniauth_authorize_path)
    expect(routes).to respond_to(:user_cityos_dcp_login_omniauth_callback_path)
  end

  it "uses Decidim's standard icon path labels", skip: !cityos_gem_available do
    key = "decidim.system.organizations.omniauth_settings.icon_path"

    expect(I18n.t(key, locale: :ja)).to eq("アイコンのパス")
    expect(I18n.t(key, locale: :en)).to eq("Icon path")
  end

  it "does not require a CityOS icon by default", skip: !cityos_gem_available do
    expect(Rails.application.secrets.dig(:omniauth, :cityos_dcp_login, :icon_path)).to be_nil
  end

  it "keeps the legacy client credential environment names as fallbacks", skip: !cityos_gem_available do
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
