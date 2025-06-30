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

  # Test integration with actual Decidim models
  describe "integration with Decidim models" do
    let(:organization) { create(:organization) }
    let(:user) { create(:user, organization:) }
    let(:editor_image) { create(:editor_image, author: user, organization:) }
    let(:blob) { editor_image.file.blob }
    let(:s3_url) { "https://test-bucket.s3.amazonaws.com/#{blob.key}?signature=abc123" }

    before do
      allow(Decidim::Cfj::UrlConverter).to receive(:s3_url_to_global_id)
        .with(s3_url)
        .and_return(blob.to_global_id.to_s)
    end

    context "with blog posts" do
      let(:participatory_process) { create(:participatory_process, organization:) }
      let(:component) { create(:component, manifest_name: :blogs, participatory_space: participatory_process) }
      let(:blog_post_content) { "<p>Blog content with image: <img src=\"#{s3_url}\" alt=\"Test image\"></p>" }

      it "processes S3 URLs in blog post content" do
        parser = Decidim::ContentParsers::BlobParser.new(blog_post_content, {})
        result = parser.rewrite

        expect(result).to include(blob.to_global_id.to_s)
        expect(result).not_to include("s3.amazonaws.com")
        expect(result).to include("<img src=\"#{blob.to_global_id}\" alt=\"Test image\">")
      end
    end

    context "with proposal answers" do
      let(:participatory_process) { create(:participatory_process, organization:) }
      let(:component) { create(:component, manifest_name: :proposals, participatory_space: participatory_process) }
      let(:proposal_answer_content) { "<p>Proposal answer with image: <img src=\"#{s3_url}\" alt=\"Answer image\"></p>" }

      it "processes S3 URLs in proposal answer content" do
        parser = Decidim::ContentParsers::BlobParser.new(proposal_answer_content, {})
        result = parser.rewrite

        expect(result).to include(blob.to_global_id.to_s)
        expect(result).not_to include("s3.amazonaws.com")
        expect(result).to include("<img src=\"#{blob.to_global_id}\" alt=\"Answer image\">")
      end
    end

    context "with multilingual content" do
      let(:multilingual_content) do
        {
          "ja" => "<p>日本語の内容 <img src=\"#{s3_url}\" alt=\"画像\"></p>",
          "en" => "<p>English content <img src=\"#{s3_url}\" alt=\"image\"></p>"
        }
      end

      it "processes S3 URLs in each language version" do
        multilingual_content.each do |_locale, content|
          parser = Decidim::ContentParsers::BlobParser.new(content, {})
          result = parser.rewrite

          expect(result).to include(blob.to_global_id.to_s)
          expect(result).not_to include("s3.amazonaws.com")
        end
      end
    end

    context "with mixed URL types in same content" do
      let(:rails_blob_url) { Rails.application.routes.url_helpers.rails_blob_url(blob, only_path: true) }
      let(:mixed_content) do
        <<~HTML
          <p>Content with multiple URL types:</p>
          <p>S3 URL: <img src="#{s3_url}" alt="S3 image"></p>
          <p>Rails URL: <img src="#{rails_blob_url}" alt="Rails image"></p>
          <p>Regular URL: <img src="https://example.com/image.jpg" alt="External image"></p>
        HTML
      end

      it "processes only blob URLs and leaves other URLs unchanged" do
        parser = Decidim::ContentParsers::BlobParser.new(mixed_content, {})
        result = parser.rewrite

        # Should convert both S3 and Rails URLs to Global IDs
        expect(result.scan("gid://").count).to eq(2)
        expect(result).not_to include("s3.amazonaws.com")
        expect(result).not_to include("/rails/active_storage/blobs/")

        # Should preserve external URL
        expect(result).to include("https://example.com/image.jpg")
      end
    end
  end
end
