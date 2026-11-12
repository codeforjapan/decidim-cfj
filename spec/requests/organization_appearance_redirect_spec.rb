# frozen_string_literal: true

require "rails_helper"

# Covers config/initializers/organization_appearance_redirect_override.rb.
RSpec.describe "Removed organization appearance page" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization) }
  let(:appearance_path) { "/#{organization.default_locale}/admin/organization/appearance/edit" }
  let(:settings_path) { "/#{organization.default_locale}/admin/organization/edit" }

  before do
    host! organization.host
  end

  context "when an admin opens the old URL" do
    let(:admin_user) { create(:user, :admin, :confirmed, organization:) }

    before { sign_in admin_user, scope: :user }

    it "redirects to the organization settings" do
      get appearance_path

      expect(response).to redirect_to(settings_path)
    end

    it "redirects the old form submission to the organization settings" do
      patch "/#{organization.default_locale}/admin/organization/appearance"

      expect(response).to redirect_to(settings_path)
    end
  end

  context "when a participant opens the old URL" do
    let(:user) { create(:user, :confirmed, organization:) }

    before { sign_in user, scope: :user }

    it "does not show the organization settings" do
      get appearance_path

      expect(response).not_to redirect_to(settings_path)
    end
  end
end
