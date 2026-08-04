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
end
