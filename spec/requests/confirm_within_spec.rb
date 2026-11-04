# frozen_string_literal: true

require "rails_helper"

# Covers config/initializers/confirm_within.rb.
RSpec.describe "Confirmation link expiry" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization) }
  let(:token) { "confirmation-token" }
  let(:confirm) { get "/users/confirmation", params: { confirmation_token: token } }
  let(:resend) { post "/users/confirmation", params: { user: { email: resend_to } } }

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

      context "when a new link is requested from the resend form" do
        let(:resend_to) { user.email }

        it "sends a new link" do
          expect { resend }.to have_enqueued_mail(Decidim::DecidimDeviseMailer, :confirmation_instructions)
          expect(user.reload.confirmation_token).not_to eq(token)
        end
      end

      context "when the email was changed before confirming the account" do
        let(:resend_to) { user.email }

        before { user.update_columns(unconfirmed_email: "new-address@example.org") } # rubocop:disable Rails/SkipsModelValidations

        it "does not send a new link" do
          expect { resend }.not_to have_enqueued_mail(Decidim::DecidimDeviseMailer, :confirmation_instructions)
          expect(user.reload.confirmation_token).to eq(token)
        end
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

      context "when the link is requested again from the resend form" do
        let(:resend_to) { "new-address@example.org" }

        it "sends the link again" do
          expect { resend }.to have_enqueued_mail(Decidim::DecidimDeviseMailer, :confirmation_instructions)
          expect(user.reload.confirmation_token).to eq(token)
        end
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

      context "when a new link is requested from the resend form with the new email" do
        let(:resend_to) { "new-address@example.org" }

        it "does not send a new link" do
          expect { resend }.not_to have_enqueued_mail(Decidim::DecidimDeviseMailer, :confirmation_instructions)
          expect(user.reload.confirmation_token).to eq(token)
        end
      end

      context "when a new link is requested from the resend form with the current email" do
        let(:resend_to) { old_email }

        it "does not send a new link" do
          expect { resend }.not_to have_enqueued_mail(Decidim::DecidimDeviseMailer, :confirmation_instructions)
          expect(user.reload.confirmation_token).to eq(token)
        end
      end

      context "when a new link is requested from the account page" do
        let(:resend_from_account) do
          perform_enqueued_jobs(only: Decidim::ResendConfirmationInstructionsJob) do
            post "/account/resend_confirmation_instructions", xhr: true
          end
        end

        before { sign_in user, scope: :user }

        it "sends a new link" do
          expect { resend_from_account }.to have_enqueued_mail(Decidim::DecidimDeviseMailer, :confirmation_instructions)
          expect(user.reload.confirmation_token).not_to eq(token)
        end
      end
    end
  end
end
