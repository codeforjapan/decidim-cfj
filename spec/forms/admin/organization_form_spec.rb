# frozen_string_literal: true

require "rails_helper"

module Decidim
  module Admin
    describe OrganizationForm do
      let(:organization) { create(:organization) }
      let(:current_organization) { organization }

      let(:params) do
        {
          mobile_logo:,
          remove_mobile_logo:
        }
      end

      let(:mobile_logo) { nil }
      let(:remove_mobile_logo) { false }

      let(:form) do
        described_class.from_model(organization)
                       .with_context(current_organization: organization)
                       .tap { |form| form.assign_attributes(params) }
      end

      describe "validations" do
        context "with valid mobile logo file" do
          let(:mobile_logo) { Decidim::Dev.test_file("city.jpeg", "image/jpeg") }

          it "is valid" do
            expect(form).to be_valid
          end
        end

        context "with invalid mobile logo file type" do
          let(:mobile_logo) { Decidim::Dev.test_file("participatory_text.md", "text/markdown") }

          it "is invalid" do
            expect(form).not_to be_valid
            expect(form.errors[:mobile_logo]).to be_present
          end
        end
      end
    end
  end
end
