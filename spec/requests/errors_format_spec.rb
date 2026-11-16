# frozen_string_literal: true

require "rails_helper"

# Covers config/initializers/errors_controller_format_override.rb.
#
# In production a missing file requested with a non-HTML format (for example
# /missing.css with the Accept header a browser sends for stylesheets) reaches
# the exceptions app with that format. These requests call the error pages with
# the format directly.
RSpec.describe "Error pages" do
  let(:organization) { create(:organization) }

  before { host! organization.host }

  %w(css png xml zip).each do |extension|
    context "when the not found page is requested as .#{extension}" do
      it "responds with 404 without a body" do
        get "/404.#{extension}"

        expect(response).to have_http_status(:not_found)
        expect(response.body).to be_empty
      end
    end
  end

  context "when the internal server error page is requested as .png" do
    it "responds with 500 without a body" do
      get "/500.png"

      expect(response).to have_http_status(:internal_server_error)
      expect(response.body).to be_empty
    end
  end

  context "when the not found page is requested as HTML" do
    it "renders the page" do
      get "/404"

      expect(response).to have_http_status(:not_found)
      expect(response.media_type).to eq("text/html")
      expect(response.body).to include("<html")
    end
  end
end
