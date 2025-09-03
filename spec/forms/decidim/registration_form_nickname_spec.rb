# frozen_string_literal: true

require "rails_helper"

module Decidim
  describe RegistrationForm do
    subject { form }

    let(:organization) { create(:organization) }
    let(:name) { "Test User" }
    let(:email) { "test@example.com" }
    let(:password) { "DfyvHn425mYAy2HL" }
    let(:tos_agreement) { "1" }
    let(:nickname) { "test_user" }

    let(:params) do
      {
        user: {
          name:,
          email:,
          nickname:,
          password:,
          tos_agreement:
        }
      }
    end

    let(:form) do
      described_class.from_params(params[:user]).with_context(
        current_organization: organization
      )
    end

    context "when nickname is provided" do
      it "uses the provided nickname" do
        expect(form.nickname).to eq("test_user")
      end

      it "validates nickname format" do
        expect(form).to be_valid
      end

      context "with invalid nickname format" do
        let(:nickname) { "invalid@nickname" }

        it "is invalid" do
          expect(form).not_to be_valid
          expect(form.errors[:nickname]).to include("は不正な値です")
        end
      end

      context "with duplicate nickname" do
        before do
          create(:user, nickname: "test_user", organization:)
        end

        it "is invalid" do
          expect(form).not_to be_valid
          expect(form.errors[:nickname]).to include("はすでに存在します")
        end
      end

      context "with too long nickname" do
        let(:nickname) { "a" * 25 }

        it "is invalid" do
          expect(form).not_to be_valid
          expect(form.errors[:nickname]).to be_present
        end
      end
    end

    context "when nickname is empty" do
      let(:nickname) { "" }

      it "generates nickname from name" do
        expect(form.nickname).to eq("Test_User")
      end
    end

    context "when nickname is nil" do
      let(:nickname) { nil }

      it "generates nickname from name" do
        expect(form.nickname).to eq("Test_User")
      end
    end
  end
end
