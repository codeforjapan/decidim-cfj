# frozen_string_literal: true

require "rails_helper"
require "decidim/system/test/factories"

# Sidekiq::Web shows the queue shared by every organization, so it must only be
# reachable by system admins.
RSpec.describe "Sidekiq::Web access" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization) }
  let(:system_admin_sign_in_url) { "http://#{organization.host}/system/admins/sign_in" }

  before { host! organization.host }

  context "when not signed in" do
    before { get "/sidekiq" }

    it "redirects to the system admin sign in" do
      expect(response).to redirect_to(system_admin_sign_in_url)
    end
  end

  context "when signed in as a participant" do
    let(:participant) { create(:user, :confirmed, organization:) }

    before do
      sign_in participant, scope: :user
      get "/sidekiq"
    end

    it "redirects to the system admin sign in" do
      expect(response).to redirect_to(system_admin_sign_in_url)
    end
  end

  context "when signed in as an organization admin" do
    let(:admin_user) { create(:user, :admin, :confirmed, organization:) }

    before do
      sign_in admin_user, scope: :user
      get "/sidekiq"
    end

    it "redirects to the system admin sign in" do
      expect(response).to redirect_to(system_admin_sign_in_url)
    end
  end

  context "when signed in as a system admin" do
    let(:system_admin) { create(:user, :admin, :confirmed, organization:) }

    before do
      sign_in system_admin, scope: :admin
      get "/sidekiq"
    end

    it "shows the dashboard" do
      expect(response).to have_http_status(:ok)
    end
  end
end
