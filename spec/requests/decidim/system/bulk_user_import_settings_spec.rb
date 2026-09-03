# frozen_string_literal: true

require "rails_helper"

# /system の一括アカウント発行設定（Decidim::System::BulkUserImportSettingsController）
RSpec.describe "Decidim::System BulkUserImportSettingsController" do
  include Devise::Test::IntegrationHelpers

  let!(:organization) { create(:organization) }
  # decidim-system のファクトリはこのアプリでは読み込まれないため直接作る
  let(:system_admin) do
    Decidim::System::Admin.create!(email: "system@example.org",
                                   password: "decidim123456789",
                                   password_confirmation: "decidim123456789")
  end

  before { host! organization.host }

  context "without a signed in system admin" do
    it "redirects to the system sign in page" do
      get "/system/bulk_user_import_settings"

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("sign_in")
    end

    it "does not accept updates" do
      patch "/system/bulk_user_import_settings/#{organization.id}",
            params: { bulk_user_import_setting: { email_domain: "x", enabled: "1" } }

      expect(response).to have_http_status(:redirect)
      expect(Decidim::BulkUserImportSetting.count).to eq(0)
    end
  end

  context "with a system admin" do
    before { sign_in system_admin }

    it "lists the organizations with their settings" do
      Decidim::BulkUserImportSetting.create!(organization:, email_domain: "chiba-mirai.test", enabled: true)

      get "/system/bulk_user_import_settings"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(organization.host)
      expect(response.body).to include("chiba-mirai.test")
    end

    it "enables issuing with a domain" do
      patch "/system/bulk_user_import_settings/#{organization.id}",
            params: { bulk_user_import_setting: { email_domain: "chiba-mirai.test", enabled: "1" } }

      expect(response).to redirect_to("/system/bulk_user_import_settings")
      setting = Decidim::BulkUserImportSetting.find_by(decidim_organization_id: organization.id)
      expect(setting.enabled).to be(true)
      expect(setting.email_domain).to eq("chiba-mirai.test")
    end

    it "rejects enabling without a domain" do
      patch "/system/bulk_user_import_settings/#{organization.id}",
            params: { bulk_user_import_setting: { email_domain: "", enabled: "1" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Decidim::BulkUserImportSetting.find_by(decidim_organization_id: organization.id)).to be_nil
    end

    it "rejects a domain that would break the email format" do
      patch "/system/bulk_user_import_settings/#{organization.id}",
            params: { bulk_user_import_setting: { email_domain: "Chiba Mirai", enabled: "1" } }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects a domain without a dot (it would fail the sign-in form validation)" do
      patch "/system/bulk_user_import_settings/#{organization.id}",
            params: { bulk_user_import_setting: { email_domain: "chiba-mirai", enabled: "1" } }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "can disable issuing while keeping the domain" do
      Decidim::BulkUserImportSetting.create!(organization:, email_domain: "chiba-mirai.test", enabled: true)

      patch "/system/bulk_user_import_settings/#{organization.id}",
            params: { bulk_user_import_setting: { email_domain: "chiba-mirai.test", enabled: "0" } }

      expect(response).to have_http_status(:redirect)
      expect(Decidim::BulkUserImportSetting.find_by(decidim_organization_id: organization.id).enabled).to be(false)
    end
  end
end
