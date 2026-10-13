# frozen_string_literal: true

require "rails_helper"

# Covers config/initializers/organization_session_binding.rb.
RSpec.describe "Session bound to the organization" do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:password) { "decidim123456789" }
  let(:user) { create(:user, :confirmed, organization:, password:) }
  let(:remember_me) { "0" }
  let(:locked) { false }
  let(:session_key) { Rails.application.config.session_options[:key] }
  let(:replayed_cookies) { [session_key] }
  let(:cookie_header) { replayed_cookies.map { |name| "#{name}=#{CGI.escape(cookies[name])}" }.join("; ") }
  let(:session_query) { { query: "{ session { user { id } } }" } }
  let(:session_data) { response.parsed_body["data"]["session"] }

  before do
    host! organization.host
    post "/users/sign_in", params: { user: { email: user.email, password:, remember_me: } }
    user.lock_access! if locked
    host! target_host
    post "/api", params: session_query, headers: { "Cookie" => cookie_header }
  end

  context "when the session is replayed on the user's organization" do
    let(:target_host) { organization.host }

    it "keeps the user signed in on the API" do
      expect(response).to have_http_status(:ok)
      expect(session_data).to eq("user" => { "id" => user.id.to_s })
    end
  end

  context "when the session is replayed on another organization" do
    let(:target_host) { other_organization.host }

    it "treats the user as signed out on the API" do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("data" => { "session" => nil })
    end

    it "treats the user as signed out on the front end" do
      get "/account", headers: { "Cookie" => cookie_header }

      expect(response).to redirect_to("/users/sign_in")
    end

    it "leaves the shared session untouched" do
      expect(request.session["warden.user.user.key"]).to be_present
      expect(request.session_options[:renew]).to be_falsey
    end

    it "keeps the session valid on the user's organization" do
      host! organization.host
      post "/api", params: session_query, headers: { "Cookie" => cookie_header }

      expect(session_data).to eq("user" => { "id" => user.id.to_s })
    end

    it "signs out without invalidating the user's other sessions" do
      session_token = user.reload.session_token

      delete "/users/sign_out", headers: { "Cookie" => cookie_header }

      expect(response).to have_http_status(:found)
      expect(user.reload.session_token).to eq(session_token)
    end
  end

  context "when a locked user's session is replayed on another organization" do
    let(:target_host) { other_organization.host }
    let(:locked) { true }

    it "treats the user as signed out without signing them out elsewhere" do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("data" => { "session" => nil })
      expect(request.session["warden.user.user.key"]).to be_present
    end

    it "treats the user as signed out on the front end without touching the session" do
      get "/account", headers: { "Cookie" => cookie_header }

      expect(response).to redirect_to("/users/sign_in")
      expect(request.session["warden.user.user.key"]).to be_present
    end
  end

  context "when the remember-me cookie is replayed on the user's organization" do
    let(:target_host) { organization.host }
    let(:remember_me) { "1" }
    let(:replayed_cookies) { %w(remember_user_token) }

    it "keeps the user signed in" do
      expect(response).to have_http_status(:ok)
      expect(session_data).to eq("user" => { "id" => user.id.to_s })
    end
  end

  context "when the remember-me cookie is replayed on another organization" do
    let(:target_host) { other_organization.host }
    let(:remember_me) { "1" }
    let(:replayed_cookies) { %w(remember_user_token) }

    it "treats the user as signed out" do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("data" => { "session" => nil })
    end

    it "treats the user as signed out on the front end" do
      get "/account", headers: { "Cookie" => cookie_header }

      expect(response).to redirect_to("/users/sign_in")
    end

    it "does not forget the user on the user's organization" do
      expect(user.reload.remember_created_at).to be_present
    end

    it "does not record a sign-in" do
      expect(user.reload.sign_in_count).to eq(1)
    end
  end

  context "when both cookies are replayed on another organization" do
    let(:target_host) { other_organization.host }
    let(:remember_me) { "1" }
    let(:replayed_cookies) { [session_key, "remember_user_token"] }

    it "treats the user as signed out" do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("data" => { "session" => nil })
    end

    it "leaves the shared session untouched" do
      expect(request.session["warden.user.user.key"]).to be_present
      expect(request.session_options[:renew]).to be_falsey
    end

    it "treats the user as signed out on the front end without touching the session" do
      get "/account", headers: { "Cookie" => cookie_header }

      expect(response).to redirect_to("/users/sign_in")
      expect(request.session["warden.user.user.key"]).to be_present
      expect(request.session_options[:renew]).to be_falsey
    end

    it "does not forget the user or record a sign-in" do
      expect(user.reload.remember_created_at).to be_present
      expect(user.sign_in_count).to eq(1)
    end
  end
end
