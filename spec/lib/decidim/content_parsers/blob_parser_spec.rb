# frozen_string_literal: true

require "rails_helper"

describe "BlobParser with S3 URL support" do
  # This is an integration test for the extended BlobParser functionality
  let(:blob) { create(:blob, :image) }
  let(:s3_url) { "https://bucket-name.s3.us-east-1.amazonaws.com/#{blob.key}?signature=xyz" }
  let(:rails_blob_url) { Rails.application.routes.url_helpers.rails_blob_url(blob, only_path: true) }
  let(:global_id) { blob.to_global_id.to_s }
  let(:parser) { Decidim::ContentParsers::BlobParser.new(content, {}) }

  before do
    # Mock the UrlConverter to return a Global ID for S3 URLs
    allow(Decidim::Cfj::UrlConverter).to receive(:s3_url_to_global_id).and_call_original
    allow(Decidim::Cfj::UrlConverter).to receive(:s3_url_to_global_id)
      .with(s3_url)
      .and_return(global_id)
  end

  describe "#rewrite" do
    subject { parser.rewrite }

    context "when content contains S3 URLs" do
      let(:content) do
        <<~HTML
          <p>Here is an image: <img src="#{s3_url}" alt="S3 image"></p>
          <p>And some text with a link to <a href="#{s3_url}">the image</a></p>
        HTML
      end

      it "replaces S3 URLs with Global IDs" do
        expect(subject).to include(global_id)
        expect(subject).not_to include("s3.amazonaws.com")
      end

      it "preserves the HTML structure" do
        expect(subject).to include("<img src=\"#{global_id}\" alt=\"S3 image\">")
        expect(subject).to include("<a href=\"#{global_id}\">the image</a>")
      end
    end

    context "when content contains Rails blob URLs" do
      let(:content) do
        <<~HTML
          <p>Here is an image: <img src="#{rails_blob_url}" alt="Rails blob image"></p>
        HTML
      end

      it "replaces Rails blob URLs with Global IDs" do
        expect(subject).to include(global_id)
        expect(subject).not_to include("/rails/active_storage/blobs/")
      end
    end

    context "when content contains both S3 and Rails blob URLs" do
      let(:another_blob) { create(:blob, :image) }
      let(:another_s3_url) { "https://bucket.s3.amazonaws.com/#{another_blob.key}" }
      let(:another_rails_url) { Rails.application.routes.url_helpers.rails_blob_url(another_blob, only_path: true) }
      let(:another_global_id) { another_blob.to_global_id.to_s }

      let(:content) do
        <<~HTML
          <p>S3 image: <img src="#{s3_url}"></p>
          <p>Rails blob image: <img src="#{rails_blob_url}"></p>
          <p>Another S3: <img src="#{another_s3_url}"></p>
          <p>Another Rails: <img src="#{another_rails_url}"></p>
        HTML
      end

      before do
        allow(Decidim::Cfj::UrlConverter).to receive(:s3_url_to_global_id)
          .with(another_s3_url)
          .and_return(another_global_id)
      end

      it "replaces all URLs with their respective Global IDs" do
        result = subject
        expect(result.scan("gid://").count).to eq(4)
        expect(result).not_to include("s3.amazonaws.com")
        expect(result).not_to include("/rails/active_storage/blobs/")
      end
    end

    context "when S3 URL conversion fails" do
      let(:invalid_s3_url) { "https://unknown-bucket.s3.amazonaws.com/unknown-key" }
      let(:content) do
        <<~HTML
          <p>Valid: <img src="#{s3_url}"></p>
          <p>Invalid: <img src="#{invalid_s3_url}"></p>
        HTML
      end

      before do
        allow(Decidim::Cfj::UrlConverter).to receive(:s3_url_to_global_id)
          .with(invalid_s3_url)
          .and_return(nil)
      end

      it "keeps the original URL when conversion fails" do
        result = subject
        expect(result).to include(global_id)
        expect(result).to include(invalid_s3_url)
      end
    end

    context "when content has no blob URLs" do
      let(:content) do
        <<~HTML
          <p>Just some regular text</p>
          <p>With a <a href="https://example.com">regular link</a></p>
        HTML
      end

      it "returns the content unchanged" do
        expect(subject).to eq(content)
      end
    end
  end
end
