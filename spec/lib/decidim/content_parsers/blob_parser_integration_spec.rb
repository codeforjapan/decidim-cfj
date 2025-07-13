# frozen_string_literal: true

require "rails_helper"

describe "BlobParser integration with Decidim rich text processing" do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization:) }
  let(:editor_image) { create(:editor_image, author: user, organization:) }
  let(:blob) { editor_image.file.blob }
  let(:s3_url) { "https://test-bucket.s3.amazonaws.com/#{blob.key}?signature=abc123" }
  let(:global_id) { blob.to_global_id.to_s }

  before do
    allow(Decidim::Cfj::UrlConverter).to receive(:s3_url_to_global_id)
      .with(s3_url)
      .and_return(global_id)
  end

  describe "with blog posts" do
    let(:participatory_process) { create(:participatory_process, organization:) }
    let(:component) { create(:component, manifest_name: :blogs, participatory_space: participatory_process) }
    let(:content_with_s3_url) { "<p>Blog post with S3 image: <img src=\"#{s3_url}\" alt=\"Test\"></p>" }

    it "processes content when creating a blog post" do
      # Simulate the content processing that happens during model save
      processed_content = Decidim::ContentParsers::BlobParser.new(content_with_s3_url, {}).rewrite

      expect(processed_content).to include(global_id)
      expect(processed_content).not_to include("s3.amazonaws.com")
      expect(processed_content).to include("<img src=\"#{global_id}\" alt=\"Test\">")
    end

    it "handles content with multiple images" do
      another_blob = create(:blob, :image)
      another_s3_url = "https://test-bucket.s3.amazonaws.com/#{another_blob.key}?signature=xyz"
      another_global_id = another_blob.to_global_id.to_s

      allow(Decidim::Cfj::UrlConverter).to receive(:s3_url_to_global_id)
        .with(another_s3_url)
        .and_return(another_global_id)

      multi_image_content = <<~HTML
        <p>First image: <img src="#{s3_url}" alt="First"></p>
        <p>Second image: <img src="#{another_s3_url}" alt="Second"></p>
      HTML

      processed_content = Decidim::ContentParsers::BlobParser.new(multi_image_content, {}).rewrite

      expect(processed_content).to include(global_id)
      expect(processed_content).to include(another_global_id)
      expect(processed_content).not_to include("s3.amazonaws.com")
      expect(processed_content.scan("gid://").count).to eq(2)
    end
  end

  describe "with proposal answers" do
    let(:participatory_process) { create(:participatory_process, organization:) }
    let(:component) { create(:component, manifest_name: :proposals, participatory_space: participatory_process) }
    let(:answer_content) { "<p>Answer with image: <img src=\"#{s3_url}\" alt=\"Answer\"></p>" }

    it "processes content when creating a proposal answer" do
      processed_content = Decidim::ContentParsers::BlobParser.new(answer_content, {}).rewrite

      expect(processed_content).to include(global_id)
      expect(processed_content).not_to include("s3.amazonaws.com")
      expect(processed_content).to include("<img src=\"#{global_id}\" alt=\"Answer\">")
    end
  end

  describe "error handling" do
    it "gracefully handles malformed URLs" do
      malformed_content = '<p>Bad URL: <img src="https://not-a-valid-s3-url" alt="Bad"></p>'

      processed_content = Decidim::ContentParsers::BlobParser.new(malformed_content, {}).rewrite

      # Should return content unchanged when URL doesn't match S3 pattern
      expect(processed_content).to eq(malformed_content)
    end

    it "handles conversion failures gracefully" do
      failing_s3_url = "https://unknown-bucket.s3.amazonaws.com/unknown-key"
      content_with_failing_url = "<p>Image: <img src=\"#{failing_s3_url}\" alt=\"Fail\"></p>"

      allow(Decidim::Cfj::UrlConverter).to receive(:s3_url_to_global_id)
        .with(failing_s3_url)
        .and_return(nil)

      processed_content = Decidim::ContentParsers::BlobParser.new(content_with_failing_url, {}).rewrite

      # Should preserve original URL when conversion fails
      expect(processed_content).to include(failing_s3_url)
      expect(processed_content).not_to include("gid://")
    end
  end

  describe "performance with large content" do
    it "handles content with many URLs efficiently" do
      # Create content with 10 S3 URLs
      large_content = (1..10).map do |i|
        test_url = "https://test-bucket.s3.amazonaws.com/key#{i}?signature=sig#{i}"
        test_global_id = "gid://decidim-app/ActiveStorage::Blob/#{i}"

        allow(Decidim::Cfj::UrlConverter).to receive(:s3_url_to_global_id)
          .with(test_url)
          .and_return(test_global_id)

        "<p>Image #{i}: <img src=\"#{test_url}\" alt=\"Image #{i}\"></p>"
      end.join("\n")

      start_time = Time.current
      processed_content = Decidim::ContentParsers::BlobParser.new(large_content, {}).rewrite
      processing_time = Time.current - start_time

      expect(processing_time).to be < 1.0 # Should complete within 1 second
      expect(processed_content.scan("gid://").count).to eq(10)
      expect(processed_content).not_to include("s3.amazonaws.com")
    end
  end
end
