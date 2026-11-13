# frozen_string_literal: true

require "rails_helper"

# Covers config/initializers/omniauth_failure_message_override.rb.
RSpec.describe "OmniAuth failure message" do
  let(:organization) { create(:organization, omniauth_settings:) }
  let(:omniauth_settings) do
    Decidim::Cfj::CityosOmniauthConfiguration::REQUIRED_KEYS
      .to_h { |key| ["omniauth_settings_cityos_dcp_login_#{key}", Decidim::AttributeEncryptor.encrypt("#{key}.example.com")] }
      .merge("omniauth_settings_cityos_dcp_login_enabled" => true)
  end
  let(:description) { "Description sent by the provider" }
  let(:callback) { get "/users/auth/cityos_dcp_login/callback", params: { error:, error_description: description } }
  let(:reasons) { "decidim.devise.omniauth_registrations.failure_reasons" }

  before do
    host! organization.host
    # Production keeps the session in the cache store, where the strategy runs without the cookie store.
    allow_any_instance_of(OmniAuth::Strategies::CityosDcpLogin).to receive(:cookie_store?).and_return(false) # rubocop:disable RSpec/AnyInstance
    callback
  end

  context "when the sign in is canceled at the provider" do
    let(:error) { "access_denied" }

    it "shows the message for the error code" do
      expect(flash[:alert]).to include(I18n.t("access_denied", scope: reasons))
    end
  end

  context "when the provider returns any other error" do
    let(:error) { "server_error" }

    it "shows the default message" do
      expect(flash[:alert]).to include(I18n.t("default", scope: reasons))
    end

    it "does not show the description sent by the provider" do
      expect(flash[:alert]).not_to include(description)
    end
  end

  context "when the error code is not one of the known codes" do
    let(:error) { "Error code sent by the provider" }

    it "shows the default message" do
      expect(flash[:alert]).to include(I18n.t("default", scope: reasons))
      expect(flash[:alert]).not_to include(error)
    end
  end
end
