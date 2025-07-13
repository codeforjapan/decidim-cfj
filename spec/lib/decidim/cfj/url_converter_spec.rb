# frozen_string_literal: true

require "rails_helper"
require_relative "../../../../lib/decidim/cfj/url_converter"

describe Decidim::Cfj::UrlConverter do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization:) }
  let(:editor_image) { create(:editor_image, author: user, organization:) }
  let(:blob) { editor_image.file.blob }

  describe ".rails_url_to_global_id" do
    context "with valid Rails blob URL" do
      let(:rails_url) { "/rails/active_storage/blobs/redirect/#{blob.signed_id}/test-image.jpg" }

      it "extracts blob ID and returns Global ID" do
        result = described_class.rails_url_to_global_id(rails_url)
        expect(result).to eq(blob.to_global_id.to_s)
      end
    end

    context "with invalid Rails URL" do
      let(:invalid_url) { "/rails/active_storage/blobs/redirect/invalid_id/test.jpg" }

      it "returns nil" do
        result = described_class.rails_url_to_global_id(invalid_url)
        expect(result).to be_nil
      end
    end

    context "with non-Rails URL" do
      let(:other_url) { "https://example.com/image.jpg" }

      it "returns nil" do
        result = described_class.rails_url_to_global_id(other_url)
        expect(result).to be_nil
      end
    end
  end

  describe ".s3_url_to_global_id" do
    context "with valid S3 URL matching existing blob" do
      let(:s3_url) { "https://test-bucket.s3.amazonaws.com/#{blob.key}?signature=abc123" }

      it "finds blob by key and returns Global ID" do
        result = described_class.s3_url_to_global_id(s3_url)
        expect(result).to eq(blob.to_global_id.to_s)
      end
    end

    context "with S3 URL for non-existent blob" do
      let(:s3_url) { "https://test-bucket.s3.amazonaws.com/nonexistent_key?signature=abc123" }

      it "returns nil" do
        result = described_class.s3_url_to_global_id(s3_url)
        expect(result).to be_nil
      end
    end

    context "with S3 URL containing filename parameter" do
      let(:s3_url) { "https://test-bucket.s3.amazonaws.com/#{blob.key}?response-content-disposition=inline%3B%20filename%3D%22test-image.jpg%22&signature=abc123" }

      it "extracts filename and tries to find blob" do
        result = described_class.s3_url_to_global_id(s3_url)
        expect(result).to eq(blob.to_global_id.to_s)
      end
    end

    context "with non-S3 URL" do
      let(:other_url) { "https://example.com/image.jpg" }

      it "returns nil" do
        result = described_class.s3_url_to_global_id(other_url)
        expect(result).to be_nil
      end
    end
  end

  describe ".global_id_to_rails_url" do
    let(:global_id) { blob.to_global_id.to_s }

    it "converts Global ID to Rails blob URL" do
      result = described_class.global_id_to_rails_url(global_id)
      expect(result).to start_with("/rails/active_storage/blobs/redirect/")
      expect(result).to include(blob.filename.to_s)
    end

    context "with invalid Global ID" do
      let(:invalid_global_id) { "gid://test/ActiveStorage::Blob/99999" }

      it "returns nil" do
        result = described_class.global_id_to_rails_url(invalid_global_id)
        expect(result).to be_nil
      end
    end
  end

  describe ".extract_key_from_s3_url" do
    it "extracts key from S3 URL" do
      s3_url = "https://test-bucket.s3.amazonaws.com/test_key_123?signature=abc123"
      result = described_class.extract_key_from_s3_url(s3_url)
      expect(result).to eq("test_key_123")
    end

    it "handles URL without query parameters" do
      s3_url = "https://test-bucket.s3.amazonaws.com/test_key_123"
      result = described_class.extract_key_from_s3_url(s3_url)
      expect(result).to eq("test_key_123")
    end
  end

  describe ".extract_filename_from_s3_url" do
    it "extracts filename from response-content-disposition parameter" do
      s3_url = "https://test-bucket.s3.amazonaws.com/key?response-content-disposition=inline%3B%20filename%3D%22test-image.jpg%22"
      result = described_class.extract_filename_from_s3_url(s3_url)
      expect(result).to eq("test-image.jpg")
    end

    it "returns nil when no filename parameter is present" do
      s3_url = "https://test-bucket.s3.amazonaws.com/key?signature=abc123"
      result = described_class.extract_filename_from_s3_url(s3_url)
      expect(result).to be_nil
    end
  end

  describe ".url_to_global_id" do
    context "with Rails URL" do
      let(:rails_url) { "/rails/active_storage/blobs/redirect/#{blob.signed_id}/test-image.jpg" }

      it "converts to Global ID" do
        result = described_class.url_to_global_id(rails_url)
        expect(result).to eq(blob.to_global_id.to_s)
      end
    end

    context "with S3 URL" do
      let(:s3_url) { "https://test-bucket.s3.amazonaws.com/#{blob.key}?signature=abc123" }

      it "converts to Global ID" do
        result = described_class.url_to_global_id(s3_url)
        expect(result).to eq(blob.to_global_id.to_s)
      end
    end

    context "with other URL" do
      let(:other_url) { "https://example.com/image.jpg" }

      it "returns nil" do
        result = described_class.url_to_global_id(other_url)
        expect(result).to be_nil
      end
    end
  end
end
