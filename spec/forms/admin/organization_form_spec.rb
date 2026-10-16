# frozen_string_literal: true

require "rails_helper"

module Decidim
  module Admin
    describe OrganizationForm do
      let(:organization) { create(:organization) }
      let(:current_organization) { organization }

      let(:mobile_logo) { nil }

      let(:form) do
        described_class.from_model(organization).with_context(
          current_organization: organization
        ).tap { |f| f.mobile_logo = mobile_logo }
      end

      describe "mobile_logo validation" do
        context "with valid mobile logo file" do
          let(:mobile_logo) { Decidim::Dev.test_file("city.jpeg", "image/jpeg") }

          it "adds no error on mobile_logo" do
            form.valid?
            expect(form.errors[:mobile_logo]).to be_empty
          end
        end

        context "with invalid mobile logo file type" do
          let(:mobile_logo) { Decidim::Dev.test_file("participatory_text.md", "text/markdown") }

          it "adds an error on mobile_logo" do
            expect(form).not_to be_valid
            expect(form.errors[:mobile_logo]).to be_present
          end
        end
      end
    end
  end
end
