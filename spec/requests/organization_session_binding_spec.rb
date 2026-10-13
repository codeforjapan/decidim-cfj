# frozen_string_literal: true

require "rails_helper"

# Covers config/initializers/organization_session_binding.rb.
RSpec.describe "Session bound to the organization" do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:password) { "decidim123456789" }
  let(:user) { create(:user, :confirmed, :admin, organization:, password:) }
  let(:remember_me) { "0" }
  let(:replayed_cookies) { [Rails.application.config.session_options[:key]] }
  let(:cookie_header) { replayed_cookies.map { |name| "#{name}=#{CGI.escape(cookies[name])}" }.join("; ") }
  let(:session_data) { response.parsed_body["data"]["session"] }

  before do
    host! organization.host
    post "/users/sign_in", params: { user: { email: user.email, password:, remember_me: } }
    host! target_host
  end

  context "when the session is replayed on the user's organization" do
    let(:target_host) { organization.host }

    it "keeps the user signed in on the API" do
      post "/api", params: { query: "{ session { user { id } } }" }, headers: { "Cookie" => cookie_header }

      expect(session_data).to eq("user" => { "id" => user.id.to_s })
    end
  end

  context "when the session is replayed on another organization" do
    let(:target_host) { other_organization.host }

    it "treats the user as signed out on the API" do
      post "/api", params: { query: "{ session { user { id } } }" }, headers: { "Cookie" => cookie_header }

      expect(session_data).to be_nil
    end

    it "treats the user as signed out on the front end" do
      get "/account", headers: { "Cookie" => cookie_header }

      expect(response).to redirect_to("/users/sign_in")
    end
  end

  context "when the remember-me cookie is replayed on the user's organization" do
    let(:target_host) { organization.host }
    let(:remember_me) { "1" }
    let(:replayed_cookies) { %w(remember_user_token) }

    it "keeps the user signed in" do
      post "/api", params: { query: "{ session { user { id } } }" }, headers: { "Cookie" => cookie_header }

      expect(session_data).to eq("user" => { "id" => user.id.to_s })
    end
  end

  context "when the remember-me cookie is replayed on another organization" do
    let(:target_host) { other_organization.host }
    let(:remember_me) { "1" }
    let(:replayed_cookies) { %w(remember_user_token) }

    it "treats the user as signed out" do
      post "/api", params: { query: "{ session { user { id } } }" }, headers: { "Cookie" => cookie_header }

      expect(session_data).to be_nil
    end
  end
end
