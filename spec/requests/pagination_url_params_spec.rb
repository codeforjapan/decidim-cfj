# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Pagination links with untrusted parameters" do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :confirmed, organization:) }
  let(:space) { create(:participatory_process, :published, organization:) }
  let(:component) { create(:proposal_component, :published, participatory_space: space) }
  let(:proposal) { create(:proposal, component:, published_at: Time.current) }

  before do
    host! organization.host
    create_list(:action_log, 26, organization:, user:, participatory_space: space, component:, resource: proposal, action: "publish", visibility: "public-only")
  end

  def pagination_hrefs
    response.parsed_body.at("[data-pagination]").css("a").map { |link| link["href"] }
  end

  it "does not use the URL options in the request to build the links" do
    get "/ja/last_activities", params: { script_name: "javascript:alert(1)//", host: "evil.example.org" }

    expect(response).to have_http_status(:ok)
    expect(pagination_hrefs).to include("/ja/last_activities?page=2")
    expect(pagination_hrefs).not_to include(a_string_matching(/javascript:|evil\.example\.org/))
  end

  it "keeps the intended page and ignores a nested params[page] option" do
    get "/ja/last_activities?params[page]=99&page=2"

    expect(response).to have_http_status(:ok)
    expect(pagination_hrefs).not_to include(a_string_including("page=99"))
  end
end
