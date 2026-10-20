# frozen_string_literal: true

require "rails_helper"
require "decidim/system/test/factories"

# Sidekiq::Web shows the queue shared by every organization, so it must only be
# reachable by system admins.
RSpec.describe "Sidekiq::Web access" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization) }
  let(:system_admin_sign_in_url) { "http://#{organization.host}/system/admins/sign_in" }

  # Sidekiq::Web itself reads Redis, which the test environment does not run.
  # Only whether the request reaches it matters here.
  before do
    allow(Sidekiq::Web).to receive(:call).and_return([200, {}, ["Sidekiq"]])
    host! organization.host
  end

  context "when not signed in" do
    before { get "/sidekiq" }

    it "redirects to the system admin sign in" do
      expect(response).to redirect_to(system_admin_sign_in_url)
      expect(Sidekiq::Web).not_to have_received(:call)
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
      expect(Sidekiq::Web).not_to have_received(:call)
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
      expect(Sidekiq::Web).not_to have_received(:call)
    end
  end

  context "when signed in as a system admin" do
    let(:system_admin) { create(:admin) }

    before do
      sign_in system_admin, scope: :admin
      get "/sidekiq"
    end

    it "passes the request to Sidekiq::Web" do
      expect(response).to have_http_status(:ok)
      expect(Sidekiq::Web).to have_received(:call)
    end
  end
end
