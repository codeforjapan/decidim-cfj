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
    # 0.31 版の互換性レポートは GitHub のリリース一覧を取りにいく
    before { stub_request(:get, %r{\Ahttps://api\.github\.com/repos/}).to_return(status: 200, body: "[]") }

    it "still renders the compatibility report" do
      get decidim_admin_decidim_awesome.checks_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST checks (system login)" do
    let!(:system_admin) { create(:admin, email: admin_user.email) }

    it "is not found" do
      post decidim_admin_decidim_awesome.checks_path

      expect(response).to have_http_status(:not_found)
    end

    it "does not sign the system admin in" do
      post decidim_admin_decidim_awesome.checks_path

      # 直前のリクエストの script_name ("/admin/decidim_awesome") を打ち消す
      get decidim_system.root_path(script_name: "")

      expect(response).to redirect_to(decidim_system.new_admin_session_path(script_name: ""))
    end
  end
end
