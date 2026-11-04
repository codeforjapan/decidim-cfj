# frozen_string_literal: true

require "rails_helper"

# Covers DecidimEscapeUriPatch in config/initializers/decidim_override.rb.
RSpec.describe "External link page" do
  let(:organization) { create(:organization) }
  let(:xhr) { false }

  before do
    host! organization.host
    get "/link", params: { external_url: }, xhr:
  end

  context "when the URL is valid" do
    let(:external_url) { "https://example.org/path?q=1" }

    it "shows the page" do
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("example.org")
    end
  end

  context "when the URL has an invalid port" do
    let(:external_url) { "http://example.org:abc/" }

    it "redirects to the root path" do
      expect(response).to redirect_to("/")
    end
  end

  context "when the host has an invalid percent-encoding" do
    let(:external_url) { "http://%FF/" }

    it "redirects to the root path" do
      expect(response).to redirect_to("/")
    end
  end

  context "when the parameter is not a string" do
    let(:external_url) { ["https://example.org/"] }

    it "redirects to the root path" do
      expect(response).to redirect_to("/")
    end
  end

  context "when requested with XHR" do
    let(:xhr) { true }

    context "when the URL is valid" do
      let(:external_url) { "https://example.org/path?q=1" }

      it "renders the warning modal" do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("external-domain-warning")
      end
    end

    context "when the URL is invalid" do
      let(:external_url) { "http://%FF/" }

      it "moves to the root path" do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('window.location.href = "/"')
        expect(flash[:alert]).to eq(I18n.t("decidim.links.invalid_url"))
      end
    end
  end
end
