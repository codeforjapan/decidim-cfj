# frozen_string_literal: true

require "rails_helper"

RSpec.describe "filter_parameter_logging initializer" do
  let(:token) { "secret-token-value" }

  describe "request parameters" do
    let(:filter) { ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters) }

    it "filters tokens and codes" do
      filtered = filter.filter(
        "reset_password_token" => token,
        "invitation_token" => token,
        "confirmation_token" => token,
        "verification_code" => token,
        "code" => token,
        "unique_id" => token
      )

      expect(filtered.values).to all(eq("[FILTERED]"))
    end
  end

  # Devise already hides its own token columns from User#inspect; these are not
  # among them.
  describe "model attributes" do
    let(:user) { build(:user, newsletter_token: token) }
    let(:authorization) { build(:authorization, unique_id: token) }

    it "are filtered from #inspect" do
      expect(user.inspect).not_to include(token)
      expect(authorization.inspect).not_to include(token)
    end
  end

  describe "redirect locations" do
    let(:filtered_location) do
      ActionDispatch::Response.new.tap do |response|
        response.request = ActionDispatch::Request.new(Rails.application.env_config.dup)
        response.location = location
      end.filtered_location
    end

    context "with an OAuth authorization code" do
      let(:location) { "https://client.example.org/callback?code=#{token}&state=xyz" }

      it { expect(filtered_location).to eq("[FILTERED]") }
    end

    context "with a token URL-encoded inside another parameter" do
      let(:location) { "https://example.org/?redirect_url=%2Fusers%2Finvitation%2Faccept%3Finvitation_token%3D#{token}" }

      it { expect(filtered_location).to eq("[FILTERED]") }
    end

    context "with a token URL-encoded twice" do
      let(:location) { "https://example.org/?next=%252Fusers%252Fpassword%252Fedit%253Freset_password_token%253D#{token}" }

      it { expect(filtered_location).to eq("[FILTERED]") }
    end

    context "without a token or code" do
      let(:location) { "https://example.org/processes?filter=all" }

      it { expect(filtered_location).to eq(location) }
    end
  end

  describe "redirect back after POST /locale", type: :request do
    let(:organization) { create(:organization) }
    let(:locations) { [] }
    let(:subscriber) do
      ActiveSupport::Notifications.subscribe("redirect_to.action_controller") { |*, payload| locations << payload[:location] }
    end

    before do
      host! organization.host
      subscriber
      post "/locale", params: { locale: "en" }, headers: { "Referer" => "http://#{organization.host}/users/invitation/accept?invitation_token=#{token}" }
    end

    after { ActiveSupport::Notifications.unsubscribe(subscriber) }

    it "filters the location carrying a token" do
      expect(response).to have_http_status(:redirect)
      expect(locations).to eq(["[FILTERED]"])
    end
  end

  describe "jobs receiving raw tokens" do
    it "do not log their arguments" do
      expect(ActionMailer::MailDeliveryJob.log_arguments?).to be(false)
      expect(Decidim::NewslettersOptInJob.log_arguments?).to be(false)
    end
  end
end
