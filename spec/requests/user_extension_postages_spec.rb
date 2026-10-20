# frozen_string_literal: true

require "rails_helper"

# The postage endpoint must only reach pending user_extension authorizations of
# the current organization.
RSpec.describe "User extension postages" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization, default_locale: :ja, available_authorizations: ["user_extension"]) }
  let(:admin_user) { create(:user, :admin, :confirmed, organization:, password_updated_at: Time.current) }
  let(:verification_metadata) { { "address" => "Tokyo", "pending_verification_code" => "123456" } }
  let(:authorization) do
    create(:authorization, :pending, name: "user_extension", user: create(:user, :confirmed, organization: authorization_organization), verification_metadata:)
  end
  let(:postage_path) { "/admin/user_extension/pending_authorizations/#{authorization.id}/postages" }

  before do
    create(:authorization, name: "user_extension", user: admin_user,
                           metadata: { real_name: "Admin", address: "Tokyo", birth_year: 1980, gender: 0 })
    host! organization.host
    sign_in admin_user, scope: :user
  end

  context "when the authorization belongs to the current organization" do
    let(:authorization_organization) { organization }

    it "marks the letter as sent" do
      post postage_path

      expect(authorization.reload.verification_metadata).to include("letter_sent_at", "verification_code" => "123456")
    end
  end

  context "when the authorization belongs to another organization" do
    let(:authorization_organization) { create(:organization, available_authorizations: ["user_extension"]) }

    # Rails 7.1 以降 show_exceptions の既定が :rescuable になり、
    # RecordNotFound は送出されず 404 として描画される。
    it "does not touch the authorization" do
      post postage_path

      expect(response).to have_http_status(:not_found)
      expect(authorization.reload.verification_metadata).to eq(verification_metadata)
    end
  end
end
