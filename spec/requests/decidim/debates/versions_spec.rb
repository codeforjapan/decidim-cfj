# frozen_string_literal: true

require "rails_helper"
require "decidim/debates/test/factories"

# Covers app/controllers/decidim/debates/versions_controller.rb.
RSpec.describe "Debate versions", versioning: true do
  let(:organization) { create(:organization) }
  let(:process) { create(:participatory_process, :published, organization:) }
  let(:component) { create(:debates_component, :published, participatory_space: process) }
  let(:debate) { create(:debate, component:) }
  let(:versions_path) { "/#{organization.default_locale}/processes/#{process.slug}/f/#{component.id}/debates/#{debate.id}/versions" }

  before { host! organization.host }

  it "shows an existing version" do
    get "#{versions_path}/1"

    expect(response).to have_http_status(:ok)
  end

  it "returns not found for a version that does not exist" do
    get "#{versions_path}/#{debate.versions.count + 1}"

    expect(response).to have_http_status(:not_found)
  end

  context "when the debate is hidden" do
    before { create(:moderation, :hidden, reportable: debate) }

    it "returns not found" do
      get "#{versions_path}/1"

      expect(response).to have_http_status(:not_found)
    end
  end

  context "when the component is not published" do
    let(:component) { create(:debates_component, :unpublished, participatory_space: process) }

    it "does not show the version" do
      get "#{versions_path}/1"

      expect(response).not_to have_http_status(:ok)
    end
  end
end
