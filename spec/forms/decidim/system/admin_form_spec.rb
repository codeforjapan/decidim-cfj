# frozen_string_literal: true

require "rails_helper"

# Covers config/initializers/system_admin_form_override.rb.
#
# Without the patch the mismatch passes validation on edit and blows up later in
# Decidim::System::UpdateAdmin, where Devise's :validatable makes `update!`
# raise.
module Decidim
  module System
    describe AdminForm do
      let(:password) { "decidim123456789" }
      let(:password_confirmation) { password }
      let(:id) { nil }

      let(:form) do
        described_class.from_params(
          admin: {
            id:,
            email: "admin@example.org",
            password:,
            password_confirmation:
          }
        )
      end

      context "when creating an admin" do
        it "is valid with a matching confirmation" do
          expect(form).to be_valid
        end

        context "with a mismatched confirmation" do
          let(:password_confirmation) { "typo123456789" }

          it "reports the mismatch once" do
            expect(form).not_to be_valid
            expect(form.errors[:password_confirmation].size).to eq(1)
          end
        end
      end

      context "when editing an admin" do
        let(:id) { 1 }

        it "is valid with a matching confirmation" do
          expect(form).to be_valid
        end

        context "with no password at all" do
          let(:password) { "" }
          let(:password_confirmation) { "" }

          it "is valid, leaving the password untouched" do
            expect(form).to be_valid
          end
        end

        context "with a mismatched confirmation" do
          let(:password_confirmation) { "typo123456789" }

          it "is invalid" do
            expect(form).not_to be_valid
            expect(form.errors[:password_confirmation]).not_to be_empty
          end
        end

        context "with only the confirmation filled in" do
          let(:password) { "" }
          let(:password_confirmation) { "typo123456789" }

          it "is invalid" do
            expect(form).not_to be_valid
            expect(form.errors[:password_confirmation]).not_to be_empty
          end
        end
      end
    end
  end
end
