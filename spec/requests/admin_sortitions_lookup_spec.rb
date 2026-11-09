# frozen_string_literal: true

require "rails_helper"
require "decidim/proposals/test/factories"
require "decidim/sortitions/test/factories"

# Covers config/initializers/sortitions_lookup_override.rb.
RSpec.describe "Admin sortition lookups" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user, :admin, :confirmed, organization:, password_updated_at: Time.current) }
  let(:process) { create(:participatory_process, organization:) }
  let(:other_organization) { create(:organization) }
  let(:other_process) { create(:participatory_process, organization: other_organization) }
  let(:manage_path) { "/admin/participatory_processes/#{process.slug}/components/#{component.id}/manage" }
  let(:component) { create(:sortition_component, participatory_space: process) }
  let(:own_sortition) { create(:sortition, component:) }
  let(:other_sortition) { create(:sortition, component: create(:sortition_component, participatory_space: other_process)) }
  let(:cancel_params) { { sortition: { id: target.id, cancel_reason: { en: "Cancel reason" } } } }

  before do
    host! organization.host
    sign_in admin_user, scope: :user
  end

  context "when cancelling a sortition of the component" do
    let(:target) { own_sortition }

    before { delete "#{manage_path}/sortitions/#{own_sortition.id}", params: cancel_params }

    it "cancels the sortition" do
      expect(own_sortition.reload).to be_cancelled
    end
  end

  context "when the form points at a sortition of another organization" do
    let(:target) { other_sortition }

    it "does not cancel the sortition" do
      expect { delete "#{manage_path}/sortitions/#{own_sortition.id}", params: cancel_params }.to raise_error(ActiveRecord::RecordNotFound)
      expect(other_sortition.reload).not_to be_cancelled
    end
  end
end
