# frozen_string_literal: true

require "rails_helper"
require "decidim/budgets/test/factories"
require "decidim/meetings/test/factories"
require "decidim/proposals/test/factories"

# Covers config/initializers/linked_resource_reference_override.rb.
RSpec.describe "Linked resource announcement" do
  let(:organization) { create(:organization) }
  let(:process) { create(:participatory_process, :published, organization:) }
  let(:proposal_component) { create(:proposal_component, :published, participatory_space: process) }
  let(:proposal) { create(:proposal, :published, component: proposal_component) }
  let(:proposal_path) { "/#{organization.default_locale}/processes/#{process.slug}/f/#{proposal_component.id}/proposals/#{proposal.id}" }
  let(:meeting_component) { create(:meeting_component, :published, participatory_space: process) }
  let(:linked_title) { "Linked resource title" }
  let(:included_in) { linked.to_gid.to_s }

  before do
    host! organization.host
    get proposal_path, params: { included_in: }
  end

  context "when the linked resource is a visible meeting of the organization" do
    let(:linked) { create(:meeting, :published, component: meeting_component, title: { en: linked_title }) }

    it "shows the linked resource" do
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(linked_title)
    end
  end

  context "when the linked resource is a visible budgets project of the organization" do
    let(:budgets_component) { create(:budgets_component, :published, participatory_space: process) }
    let(:budget) { create(:budget, component: budgets_component) }
    let(:linked) { create(:project, budget:, title: { en: linked_title }) }

    it "shows the linked resource" do
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(linked_title)
    end
  end

  context "when the linked resource belongs to another organization" do
    let(:other_component) { create(:meeting_component, :published, participatory_space: create(:participatory_process, :published)) }
    let(:linked) { create(:meeting, :published, component: other_component, title: { en: linked_title }) }

    it "does not show the linked resource" do
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(linked_title)
    end
  end

  context "when the linked resource is a private meeting" do
    let(:linked) do
      create(:meeting, :published, component: meeting_component, private_meeting: true, transparent: false, title: { en: linked_title })
    end

    it "does not show the linked resource" do
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(linked_title)
    end
  end

  context "when the linked resource is in an unpublished component" do
    let(:linked) do
      create(:meeting, :published, component: create(:meeting_component, participatory_space: process, published_at: nil), title: { en: linked_title })
    end

    it "does not show the linked resource" do
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(linked_title)
    end
  end

  context "when the linked record is not a component resource" do
    let(:linked) { create(:participatory_process, :unpublished, organization:, title: { en: linked_title }) }

    it "does not show the record" do
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(linked_title)
    end
  end

  context "when the linked record is a GlobalID" do
    let(:included_in) { "gid://#{GlobalID.app}/GlobalID/1" }

    it "shows the page without the announcement" do
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(I18n.t("decidim.linked_resource_from.included_in"))
    end
  end

  context "when the linked record does not exist" do
    let(:included_in) { "gid://#{GlobalID.app}/Decidim::Meetings::Meeting/0" }

    it "shows the page without the announcement" do
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(I18n.t("decidim.linked_resource_from.included_in"))
    end
  end
end
