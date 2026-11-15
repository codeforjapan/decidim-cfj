# frozen_string_literal: true

require "rails_helper"
require "decidim/meetings/test/factories"

# Covers config/initializers/meetings_previous_space_override.rb.
RSpec.describe "Meeting redirect notice" do
  let(:organization) { create(:organization) }
  let(:process) { create(:participatory_process, :published, organization:) }
  let(:component) { create(:meeting_component, :published, participatory_space: process) }
  let(:meeting) { create(:meeting, :published, :online, component:) }
  let(:meeting_path) { "/#{organization.default_locale}/processes/#{process.slug}/f/#{component.id}/meetings/#{meeting.id}" }
  let(:space_title) { "Previous space title" }
  let(:previous_space_param) { "#{previous_space.class.name}##{previous_space.id}" }

  before do
    host! organization.host
    get meeting_path, params: { previous_space: previous_space_param }
  end

  context "when the previous space is a published process of the organization" do
    let(:previous_space) { create(:participatory_process, :published, organization:, title: { en: space_title }) }

    it "shows the previous space" do
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(space_title)
    end
  end

  context "when the previous space belongs to another organization" do
    let(:previous_space) { create(:participatory_process, :published, title: { en: space_title }) }

    it "does not show the previous space" do
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(space_title)
    end
  end

  context "when the previous space is not published" do
    let(:previous_space) { create(:participatory_process, :unpublished, organization:, title: { en: space_title }) }

    it "does not show the previous space" do
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(space_title)
    end
  end

  context "when the previous space is not a participatory space" do
    let(:previous_space) { create(:meeting, :published, component:, title: { en: space_title }) }

    it "does not show the record" do
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(space_title)
    end
  end
end
