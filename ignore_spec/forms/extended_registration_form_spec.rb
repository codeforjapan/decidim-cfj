# frozen_string_literal: true

require "rails_helper"
require "decidim/faker/localized"

module Decidim
  describe RegistrationForm do
    subject do
      described_class.from_params(
        attributes
      ).with_context(
        context
      )
    end

    let(:organization) { create(:organization) }
    let(:name) { "User" }
    let(:nickname) { "justme" }
    let(:email) { "user@example.org" }
    let(:password) { "S4CGQ9AM4ttJdPKS" }
    let(:password_confirmation) { password }
    let(:tos_agreement) { "1" }
    let(:user_extension) do
      {
        real_name: "test real name",
        address: "test address",
        birth_year: (1931..2020).to_a.sample,
        gender: Decidim::UserExtensionForm::GENDERS.keys.sample,
        occupation: "spec builder"
      }
    end

    let(:attributes) do
      {
        name:,
        nickname:,
        email:,
        password:,
        password_confirmation:,
        tos_agreement:,
        user_extension:
      }
    end

    let(:context) do
      {
        current_organization: organization
      }
    end

    context "when everything is OK" do
      it { is_expected.to be_valid }
    end

    context "when the email is a disposable account" do
      let(:email) { "user@mailbox92.biz" }

      it { is_expected.not_to be_valid }
    end

    context "when the name is not present" do
      let(:name) { nil }

      it { is_expected.not_to be_valid }
    end

    context "when the nickname is not present" do
      let(:nickname) { nil }

      it { is_expected.not_to be_valid }
    end

    context "when the email is not present" do
      let(:email) { nil }

      it { is_expected.not_to be_valid }
    end

    context "when the email already exists" do
      let!(:user) { create(:user, organization:, email:) }

      it { is_expected.not_to be_valid }

      context "and is pending to accept the invitation" do
        let!(:user) { create(:user, organization:, email:, invitation_token: "foo", invitation_accepted_at: nil) }

        it { is_expected.not_to be_valid }
      end
    end

    context "when the nickname already exists" do
      let!(:user) { create(:user, organization:, nickname:) }

      it { is_expected.not_to be_valid }

      context "and is pending to accept the invitation" do
        let!(:user) { create(:user, organization:, nickname:, invitation_token: "foo", invitation_accepted_at: nil) }

        it { is_expected.to be_valid }
      end
    end

    context "when the nickname is too long" do
      let(:nickname) { "verylongnicknamethatcreatesanerror" }

      it { is_expected.not_to be_valid }
    end

    context "when the password is not present" do
      let(:password) { nil }

      it { is_expected.not_to be_valid }
    end

    context "when the password is weak" do
      let(:password) { "aaaabbbbcccc" }

      it { is_expected.not_to be_valid }
    end

    context "when the password confirmation is not present" do
      let(:password_confirmation) { nil }

      it { is_expected.not_to be_valid }
    end

    context "when the password confirmation is different from password" do
      let(:password_confirmation) { "invalid" }

      it { is_expected.not_to be_valid }
    end

    context "when the tos_agreement is not accepted" do
      let(:tos_agreement) { "0" }

      it { is_expected.not_to be_valid }
    end

    context "when the user_extension is not present" do
      let(:user_extension) { {} }

      it { is_expected.not_to be_valid }
    end
  end
end
