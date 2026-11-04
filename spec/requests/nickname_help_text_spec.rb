# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Nickname help text" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization, available_locales: [:ja, :en], default_locale: :ja) }
  let(:help_text) { "アルファベット小文字、数字、&#39;-&#39; および &#39;_&#39; を使用できます。" }

  before { host! organization.host }

  it "is shown on the omniauth registration form" do
    signature = Decidim::OmniauthRegistrationForm.create_signature("line", "1")
    post "/ja/omniauth_registrations",
         params: { user: { provider: "line", uid: "1", oauth_signature: signature, name: "テスト", nickname: "Invalid@ID" } }

    expect(response.body).to include("omniauth-register-form")
    expect(response.body).to include(help_text)
  end

  it "is shown on the invitation acceptance form" do
    user = create(:user, organization:)
    user.invite!

    get "/ja/users/invitation/accept", params: { invitation_token: user.raw_invitation_token }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(help_text)
  end

  it "is shown on the account settings form" do
    user = create(:user, :confirmed, organization:)
    sign_in user, scope: :user

    get "/ja/account"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(help_text)
  end
end
