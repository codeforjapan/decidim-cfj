# frozen_string_literal: true

require "rails_helper"

module Decidim
  module Admin
    describe UpdateOrganizationAppearance do
      let(:organization) { create(:organization) }
      let(:user) { create(:user, :admin, organization:) }
      let(:form_class) { OrganizationAppearanceForm }

      let(:params) do
        {
          mobile_logo:,
          remove_mobile_logo:
        }
      end

      let(:mobile_logo) { nil }
      let(:remove_mobile_logo) { false }

      let(:form) do
        form_class.from_params(params).with_context(
          current_organization: organization,
          current_user: user
        )
      end

      let(:command) { described_class.new(form, organization) }

      describe "mobile logo handling" do
        context "when uploading a new mobile logo" do
          let(:mobile_logo) { Decidim::Dev.test_file("city.jpeg", "image/jpeg") }

          it "attaches the mobile logo" do
            expect { command.call }.to broadcast(:ok)

            organization.reload
            expect(organization.mobile_logo).to be_attached
            expect(organization.mobile_logo.filename.to_s).to include("city")
          end
        end

        context "when removing mobile logo" do
          before do
            organization.mobile_logo.attach(
              io: File.open(Decidim::Dev.asset("city.jpeg")),
              filename: "existing_mobile_logo.jpg",
              content_type: "image/jpeg"
            )
          end

          let(:remove_mobile_logo) { true }

          it "removes the mobile logo" do
            expect(organization.mobile_logo).to be_attached

            expect { command.call }.to broadcast(:ok)

            organization.reload
            expect(organization.mobile_logo).not_to be_attached
          end
        end

        context "when neither uploading nor removing" do
          before do
            organization.mobile_logo.attach(
              io: File.open(Decidim::Dev.asset("city.jpeg")),
              filename: "existing_mobile_logo.jpg",
              content_type: "image/jpeg"
            )
          end

          it "keeps existing mobile logo" do
            expect { command.call }.to broadcast(:ok)

            organization.reload
            expect(organization.mobile_logo).to be_attached
            expect(organization.mobile_logo.filename.to_s).to eq("existing_mobile_logo.jpg")
          end
        end
      end
    end
  end
end
