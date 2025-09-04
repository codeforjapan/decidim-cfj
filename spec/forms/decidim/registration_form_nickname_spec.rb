# frozen_string_literal: true

require "rails_helper"

describe "RegistrationForm with nickname input" do
  let(:organization) { create(:organization) }
  let(:name) { "Test User" }
  let(:email) { "test@example.com" }
  let(:password) { "DfyvHn425mYAy2HL" }
  let(:tos_agreement) { "1" }
  let(:nickname) { "test_user" }

  let(:params) do
    {
      name:,
      email:,
      nickname:,
      password:,
      tos_agreement:
    }
  end

  let(:form) do
    Decidim::RegistrationForm.from_params(params).with_context(
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
        expect(form.errors[:nickname]).to include("is invalid")
      end
    end

    context "with duplicate nickname" do
      before do
        create(:user, nickname: "test_user", organization:)
      end

      it "is invalid" do
        expect(form).not_to be_valid
        expect(form.errors[:nickname]).to include("has already been taken")
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
      expect(form.nickname).to eq("test_user")
    end
  end

  context "when nickname is nil" do
    let(:nickname) { nil }

    it "generates nickname from name" do
      expect(form.nickname).to eq("test_user")
    end
  end
end
