# frozen_string_literal: true

require "rails_helper"

# Covers config/initializers/organization_session_binding.rb.
RSpec.describe "Session bound to the organization" do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:password) { "decidim123456789" }
  let(:user) { create(:user, :confirmed, organization:, password:) }
  let(:remember_me) { "0" }
  let(:replayed_cookies) { [Rails.application.config.session_options[:key]] }
  let(:cookie_header) { replayed_cookies.map { |name| "#{name}=#{CGI.escape(cookies[name])}" }.join("; ") }
  let(:session_data) { response.parsed_body["data"]["session"] }

  before do
    host! organization.host
    post "/users/sign_in", params: { user: { email: user.email, password:, remember_me: } }
    host! target_host
    post "/api", params: { query: "{ session { user { id } } }" }, headers: { "Cookie" => cookie_header }
  end

  context "when the session is replayed on the user's organization" do
    let(:target_host) { organization.host }

    it "keeps the user signed in on the API" do
      expect(session_data).to eq("user" => { "id" => user.id.to_s })
    end
  end

  context "when the session is replayed on another organization" do
    let(:target_host) { other_organization.host }

    it "treats the user as signed out on the API" do
      expect(session_data).to be_nil
    end

    it "treats the user as signed out on the front end" do
      get "/account", headers: { "Cookie" => cookie_header }

      expect(response).to redirect_to("/users/sign_in")
    end

    it "keeps the session valid on the user's organization" do
      host! organization.host
      post "/api", params: { query: "{ session { user { id } } }" }, headers: { "Cookie" => cookie_header }

      expect(session_data).to eq("user" => { "id" => user.id.to_s })
    end
  end

  context "when the remember-me cookie is replayed on the user's organization" do
    let(:target_host) { organization.host }
    let(:remember_me) { "1" }
    let(:replayed_cookies) { %w(remember_user_token) }

    it "keeps the user signed in" do
      expect(session_data).to eq("user" => { "id" => user.id.to_s })
    end
  end

  context "when the remember-me cookie is replayed on another organization" do
    let(:target_host) { other_organization.host }
    let(:remember_me) { "1" }
    let(:replayed_cookies) { %w(remember_user_token) }

    it "treats the user as signed out" do
      expect(session_data).to be_nil
    end

    it "does not forget the user on the user's organization" do
      expect(user.reload.remember_created_at).to be_present
    end

    it "does not record a sign-in" do
      expect(user.reload.sign_in_count).to eq(1)
    end
  end
end
