# frozen_string_literal: true

require "rails_helper"

module Decidim
  describe EditorImage do
    let(:organization) { create(:organization) }
    let(:user) { create(:user, organization:) }
    let(:editor_image) { create(:editor_image, author: user, organization:) }

    describe "#attached_uploader" do
      it "returns Rails blob URL for path method" do
        uploader = editor_image.attached_uploader(:file)

        # In test environment, the override is skipped, so we get Rails URLs
        path = uploader.path
        expect(path).to match(%r{rails/active_storage})
        expect(path).not_to match(/amazonaws\.com/)
      end

      it "maintains uploader functionality" do
        uploader = editor_image.attached_uploader(:file)

        # Other methods should still work
        expect(uploader.attached?).to be true
        expect(uploader.url).to be_present
      end
    end

    describe "GlobalID integration" do
      it "includes GlobalID::Identification" do
        expect(EditorImage.ancestors).to include(GlobalID::Identification)
      end

      it "can generate Global ID for blob" do
        blob = editor_image.file.blob
        global_id = blob.to_global_id.to_s

        expect(global_id).to start_with("gid://")
        expect(global_id).to include("ActiveStorage::Blob/#{blob.id}")
      end
    end
  end
end
