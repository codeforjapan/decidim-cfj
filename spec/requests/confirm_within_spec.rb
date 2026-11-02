# frozen_string_literal: true

require "rails_helper"

# Covers config/initializers/confirm_within.rb.
RSpec.describe "Confirmation link expiry" do
  let(:organization) { create(:organization) }
  let(:token) { "confirmation-token" }
  let(:confirm) { get "/users/confirmation", params: { confirmation_token: token } }

  before { host! organization.host }

  it "is one day by default" do
    expect(Devise.confirm_within).to eq(1.day)
  end

  describe "signing up" do
    let(:user) { create(:user, organization:) }

    before { user.update_columns(confirmation_token: token, confirmation_sent_at: sent_at) } # rubocop:disable Rails/SkipsModelValidations

    context "when the link is within the limit" do
      let(:sent_at) { 23.hours.ago }

      it "confirms the account" do
        confirm

        expect(user.reload).to be_confirmed
      end
    end

    context "when the link has expired" do
      let(:sent_at) { 25.hours.ago }

      it "does not confirm the account and offers to send a new link" do
        confirm

        expect(response.body).to include("needs to be confirmed within 1 day")
        expect(user.reload).not_to be_confirmed
      end
    end
  end

  describe "changing the email" do
    let(:user) { create(:user, :confirmed, organization:) }
    let!(:old_email) { user.email }

    before do
      user.update_columns(unconfirmed_email: "new-address@example.org", confirmation_token: token, confirmation_sent_at: sent_at) # rubocop:disable Rails/SkipsModelValidations
    end

    context "when the link is within the limit" do
      let(:sent_at) { 23.hours.ago }

      it "changes the email" do
        confirm

        expect(user.reload.email).to eq("new-address@example.org")
      end
    end

    context "when the link has expired" do
      let(:sent_at) { 25.hours.ago }

      it "keeps the old email" do
        confirm

        expect(response.body).to include("needs to be confirmed within 1 day")
        expect(user.reload.email).to eq(old_email)
        expect(user.unconfirmed_email).to eq("new-address@example.org")
      end
    end
  end
end
