# frozen_string_literal: true

require "rails_helper"

# Covers DecidimEscapeUriPatch in config/initializers/decidim_override.rb.
RSpec.describe "External link page" do
  let(:organization) { create(:organization) }

  before do
    host! organization.host
    get "/link", params: { external_url: }
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
end
