# frozen_string_literal: true

require "rails_helper"

module Decidim
  describe Organization do
    let(:organization) { create(:organization) }

    describe "mobile_logo attachment" do
      it "can attach a mobile logo" do
        organization.mobile_logo.attach(
          io: File.open(Decidim::Dev.asset("city.jpeg")),
          filename: "mobile_logo.jpg",
          content_type: "image/jpeg"
        )

        expect(organization.mobile_logo).to be_attached
        expect(organization.mobile_logo.filename.to_s).to eq("mobile_logo.jpg")
      end
    end

    describe "mobile logo uploader" do
      let(:uploader) { organization.attached_uploader(:mobile_logo) }

      before do
        organization.mobile_logo.attach(
          io: File.open(Decidim::Dev.asset("city.jpeg")),
          filename: "mobile_logo.jpg",
          content_type: "image/jpeg"
        )
      end

      it "returns OrganizationMobileLogoUploader instance" do
        expect(uploader).to be_a(Decidim::OrganizationMobileLogoUploader)
      end

      it "medium variant has correct dimensions" do
        variant_info = uploader.variants[:medium]
        expect(variant_info[:resize_to_fit]).to eq([360, 100])
      end
    end
  end
end
