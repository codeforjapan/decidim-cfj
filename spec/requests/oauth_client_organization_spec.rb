# frozen_string_literal: true

require "rails_helper"

# Covers config/initializers/oauth_client_organization_override.rb.
RSpec.describe "OAuth clients of the organization" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:user) { create(:user, :confirmed, organization:) }
  let(:own_application) { create(:oauth_application, organization:, name: "Own OAuth application") }
  let(:other_application) { create(:oauth_application, organization: other_organization, name: "Other OAuth application") }

  before do
    host! organization.host
  end

  describe "authorization request" do
    let(:authorize_params) do
      { client_id: application.uid, redirect_uri: application.redirect_uri, response_type: "code", scope: "public" }
    end

    before do
      sign_in user, scope: :user
    end

    context "when the client belongs to the organization" do
      let(:application) { own_application }

      before { get "/oauth/authorize", params: authorize_params }

      it "asks the user to authorize the client" do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Own OAuth application")
      end
    end

    context "when the client belongs to another organization" do
      let(:application) { other_application }

      it "does not ask the user to authorize the client" do
        expect { get "/oauth/authorize", params: authorize_params }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "does not issue a grant" do
        expect { post "/oauth/authorize", params: authorize_params }.to raise_error(ActiveRecord::RecordNotFound)
        expect(Doorkeeper::AccessGrant.where(application_id: other_application.id)).to be_empty
      end
    end
  end

  describe "authorization code flow of a client of the organization" do
    let(:authorize_params) do
      { client_id: own_application.uid, redirect_uri: own_application.redirect_uri, response_type: "code", scope: "public" }
    end
    let(:code) { Rack::Utils.parse_query(URI.parse(response.location).query)["code"] }
    let(:token_params) do
      {
        grant_type: "authorization_code",
        code:,
        client_id: own_application.uid,
        client_secret: own_application.secret,
        redirect_uri: own_application.redirect_uri
      }
    end

    before do
      sign_in user, scope: :user
      post "/oauth/authorize", params: authorize_params
      post "/oauth/token", params: token_params
      get "/oauth/me", headers: { "Authorization" => "Bearer #{response.parsed_body["access_token"]}", "Accept" => "application/json" }
    end

    it "returns the user data" do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["email"]).to eq(user.email)
    end
  end

  describe "user data of a token" do
    let(:headers) { { "Authorization" => "Bearer #{token.token}", "Accept" => "application/json" } }

    context "when the token was issued to a client of the organization" do
      let(:token) { create(:oauth_access_token, application: own_application, resource_owner_id: user.id) }

      before { get "/oauth/me", headers: }

      it "returns the user data" do
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["email"]).to eq(user.email)
      end
    end

    context "when the token was issued to a client of another organization" do
      let(:other_user) { create(:user, :confirmed, organization: other_organization) }
      let(:token) { create(:oauth_access_token, application: other_application, resource_owner_id: other_user.id) }

      before { get "/oauth/me", headers: }

      it "does not return the user data" do
        expect(response).to have_http_status(:unauthorized)
        expect(response.body).not_to include(other_user.email)
      end
    end

    context "when the token belongs to a user of another organization" do
      let(:other_user) { create(:user, :confirmed, organization: other_organization) }
      let(:token) { create(:oauth_access_token, application: own_application, resource_owner_id: other_user.id) }

      it "does not return the user data" do
        expect { get "/oauth/me", headers: }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
