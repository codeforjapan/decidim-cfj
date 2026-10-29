# frozen_string_literal: true

require "rails_helper"
require "decidim/system/test/factories"

RSpec.describe "Decidim::DecidimAwesome maintenance tools" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user, :admin, :confirmed, organization:) }

  before do
    host! organization.host
    sign_in admin_user, scope: :user
  end

  describe "GET hashcash" do
    it "is not allowed" do
      get decidim_admin_decidim_awesome.hashcashes_path

      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to eq(I18n.t("actions.unauthorized", scope: "decidim.core"))
    end
  end

  describe "GET private data" do
    it "is not allowed" do
      get decidim_admin_decidim_awesome.private_data_path

      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to eq(I18n.t("actions.unauthorized", scope: "decidim.core"))
    end
  end

  describe "GET checks" do
    it "still renders the compatibility report" do
      get decidim_admin_decidim_awesome.checks_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST checks (system login)" do
    let!(:system_admin) { create(:admin, email: admin_user.email) }

    it "is not routable" do
      expect { post decidim_admin_decidim_awesome.checks_path }
        .to raise_error(ActionController::RoutingError)
    end

    it "does not sign the system admin in" do
      begin
        post decidim_admin_decidim_awesome.checks_path
      rescue ActionController::RoutingError
        nil
      end

      get decidim_system.root_path

      expect(response).to redirect_to(decidim_system.new_admin_session_path)
    end
  end
end
