# frozen_string_literal: true

require "rails_helper"

# The user_extension authorization is filled in from the registration and
# account forms and stays pending, so the verification engine only serves an
# information page.
RSpec.describe "User extension authorization pages" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization, default_locale: :ja, available_authorizations: ["user_extension"]) }
  let(:user) { create(:user, :confirmed, organization:) }
  let!(:authorization) do
    create(:authorization, :pending, name: "user_extension", user:,
                                     metadata: { real_name: "Hanako", address: "Tokyo", birth_year: 1980, gender: 0 })
  end
  let(:base_path) { "/#{organization.default_locale}/user_extension/authorizations" }

  before do
    host! organization.host
    sign_in user, scope: :user
  end

  it "lists the pending authorization with a link to the information page" do
    get "/#{organization.default_locale}/authorizations"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("#{base_path}/edit")
  end

  it "shows the information page" do
    get "#{base_path}/edit"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("現在準備中です")
  end

  it "has no endpoint to create an authorization" do
    post base_path, params: { full_address: "Tokyo" }

    expect(response).to have_http_status(:not_found)
    expect(authorization.reload.verification_metadata).to eq({})
  end

  it "has no endpoint to confirm an authorization" do
    put base_path, params: { verification_code: "123456" }

    expect(response).to have_http_status(:not_found)
    expect(authorization.reload).not_to be_granted
  end
end
