# frozen_string_literal: true

require "rails_helper"
require "decidim/meetings/test/factories"

# Covers config/initializers/meeting_component_calendar_override.rb.
RSpec.describe "Meeting component calendar" do
  let(:organization) { create(:organization) }
  let(:process) { create(:participatory_process, :published, organization:) }
  let(:component) { create(:meeting_component, :published, participatory_space: process) }
  let(:public_title) { "Public meeting in the calendar" }
  let(:transparent_title) { "Transparent meeting in the calendar" }
  let(:private_title) { "Private meeting in the calendar" }

  before do
    create(:meeting, :published, :online, component:, title: { en: public_title })
    create(:meeting, :published, :online, component:, private_meeting: true, transparent: true, title: { en: transparent_title })
    create(:meeting, :published, :online, component:, private_meeting: true, transparent: false, title: { en: private_title })
    host! organization.host
    get "/processes/#{process.slug}/f/#{component.id}/calendar"
  end

  it "lists only the meetings listed publicly" do
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(public_title)
    expect(response.body).to include(transparent_title)
    expect(response.body).not_to include(private_title)
  end
end
