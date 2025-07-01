# frozen_string_literal: true

require "rails_helper"
require "decidim/blogs/test/factories"

# Test simulating production environment behavior
# Reproduce and verify actual S3 environment issues in test environment
describe "Production Environment Simulation", skip: "Temporarily skipped as not frequently needed" do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization:) }
  let(:component) { create(:component, manifest_name: "blogs", organization:) }

  before do
    login_as(user, scope: :user)
  end

  describe "Signed URL expiration simulation" do
    it "simulates the original problem and verifies the fix" do
      # Step 1: Reproduce the original problem - situation where signed URLs are stored in database
      editor_image = create(:editor_image, author: user, organization:)

      # Simulate expired signed URL (situation that occurs in actual S3 environment)
      expired_s3_url = "https://my-bucket.s3.amazonaws.com/#{editor_image.file.blob.key}?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Expires=3600&X-Amz-Date=20230101T000000Z&X-Amz-Signature=expired_signature"

      # Simulate old data (data saved by pre-fix system)
      old_blog_post = create(:post,
                             component:,
                             body: {
                               "en" => "<p>Content with expired image: <img src=\"#{expired_s3_url}\" alt=\"old image\"> End</p>",
                               "ja" => "<p>Expired image: <img src=\"#{expired_s3_url}\" alt=\"old image\"> End</p>"
                             },
                             author: user)

      # Step 2: Simulate editing with fixed system
      # When administrator edits old content
      form_params = {
        title: old_blog_post.title,
        body: old_blog_post.body, # Content containing expired S3 URL
        decidim_author_id: user.id
      }

      form = Decidim::Blogs::Admin::PostForm.from_params(form_params).with_context(
        current_user: user,
        current_organization: organization,
        current_component: component
      )

      # Step 3: Update process (BlobParser operates)
      command = Decidim::Blogs::Admin::UpdatePost.new(form, old_blog_post)

      command.call do
        on(:ok) do |updated_post|
          # Step 4: Verification - Confirm S3 URL has been converted to Global ID
          expect(updated_post.body["en"]).not_to include(expired_s3_url)
          expect(updated_post.body["en"]).to include("gid://")
          expect(updated_post.body["en"]).to include(editor_image.file.blob.to_global_id.to_s)

          expect(updated_post.body["ja"]).not_to include(expired_s3_url)
          expect(updated_post.body["ja"]).to include("gid://")
        end

        on(:invalid) do |_|
          raise "Post update failed"
        end
      end
    end
  end

  describe "Mixed URL content handling" do
    it "handles content with multiple URL types from production environment" do
      editor_image1 = create(:editor_image, author: user, organization:)
      editor_image2 = create(:editor_image, author: user, organization:)

      # Complex content that could actually occur in production environment
      mixed_content = <<~HTML
        <h2>Multiple Image Types Test</h2>

        <!-- Expired S3 URL (migration data from old system) -->
        <p>Old image: <img src="https://my-bucket.s3.amazonaws.com/#{editor_image1.file.blob.key}?X-Amz-Expires=3600&signature=expired" alt="old"></p>

        <!-- Current Rails URL (image added in editor) -->
        <p>New image: <img src="/rails/active_storage/blobs/redirect/#{editor_image2.file.blob.signed_id}/new-image.jpg" alt="new"></p>

        <!-- External URL (should be kept as-is) -->
        <p>External image: <img src="https://example.com/external-image.jpg" alt="external"></p>

        <!-- Base64 image (processed by InlineImagesParser) -->
        <p>Base64 image: <img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" alt="base64"></p>

        <!-- Relative URL (should not be changed) -->
        <p>Relative image: <img src="/assets/logo.png" alt="relative"></p>
      HTML

      # Test processing with BlobParser
      parser = Decidim::ContentParsers::BlobParser.new(mixed_content, context: { user: })
      processed_content = parser.rewrite

      # S3 URL is converted to Global ID
      expect(processed_content).not_to include("s3.amazonaws.com")
      expect(processed_content).to include(editor_image1.file.blob.to_global_id.to_s)

      # Rails URL is converted to Global ID
      expect(processed_content).not_to include("/rails/active_storage/blobs/redirect/")
      expect(processed_content).to include(editor_image2.file.blob.to_global_id.to_s)

      # External URL is kept as-is
      expect(processed_content).to include("https://example.com/external-image.jpg")

      # Relative URL is kept as-is
      expect(processed_content).to include("/assets/logo.png")
    end
  end

  describe "Load testing simulation" do
    it "handles high volume of image conversions efficiently" do
      # Content with large number of images (simulating production load)
      editor_images = 20.times.map { create(:editor_image, author: user, organization:) }

      # Large content mixing various URL formats of images
      large_content = editor_images.map.with_index do |img, index|
        case index % 4
        when 0
          # S3 URL
          "<img src=\"https://bucket-#{index}.s3.amazonaws.com/#{img.file.blob.key}?signature=test#{index}\" alt=\"s3-#{index}\">"
        when 1
          # Rails URL
          "<img src=\"/rails/active_storage/blobs/redirect/#{img.file.blob.signed_id}/file-#{index}.jpg\" alt=\"rails-#{index}\">"
        when 2
          # External URL
          "<img src=\"https://external-#{index}.com/image.jpg\" alt=\"external-#{index}\">"
        when 3
          # Relative URL
          "<img src=\"/assets/image-#{index}.png\" alt=\"relative-#{index}\">"
        end
      end.join("\n")

      # Measure processing time
      start_time = Time.current

      parser = Decidim::ContentParsers::BlobParser.new(large_content, context: { user: })
      processed_content = parser.rewrite

      end_time = Time.current
      processing_time = end_time - start_time

      # Performance verification
      expect(processing_time).to be < 2.0 # Processing completes within 2 seconds

      # Confirm all internal URLs have been converted
      expect(processed_content).not_to include("s3.amazonaws.com")
      expect(processed_content).not_to include("/rails/active_storage/blobs/redirect/")

      # Confirm external URLs and relative URLs are preserved
      expect(processed_content).to include("external-")
      expect(processed_content).to include("/assets/image-")

      # Confirm all editor_images Global IDs are included
      editor_images.each_with_index do |img, index|
        next if index % 4 >= 2 # Skip external URLs and relative URLs

        expect(processed_content).to include(img.file.blob.to_global_id.to_s)
      end
    end
  end

  describe "Error resilience in production scenarios" do
    it "gracefully handles database connection issues" do
      editor_image = create(:editor_image, author: user, organization:)
      s3_url = "https://my-bucket.s3.amazonaws.com/#{editor_image.file.blob.key}?signature=test"

      # Simulate database connection error
      allow(ActiveStorage::Blob).to receive(:find_by).and_raise(ActiveRecord::ConnectionTimeoutError)

      content = "<img src=\"#{s3_url}\" alt=\"test\">"

      # Does not crash even when error occurs
      expect do
        parser = Decidim::ContentParsers::BlobParser.new(content, context: {})
        result = parser.rewrite

        # Keep original URL when conversion fails
        expect(result).to include(s3_url)
      end.not_to raise_error
    end

    it "handles memory pressure during large content processing" do
      # Very large content (test memory usage)
      very_large_content = 1000.times.map do |i|
        "<p>Paragraph #{i}: <img src=\"https://bucket.s3.amazonaws.com/key#{i}?sig=test\" alt=\"img#{i}\"></p>"
      end.join("\n")

      # Process while monitoring memory usage
      initial_memory = `ps -o rss= -p #{Process.pid}`.to_i

      parser = Decidim::ContentParsers::BlobParser.new(very_large_content, context: {})
      result = parser.rewrite

      final_memory = `ps -o rss= -p #{Process.pid}`.to_i
      memory_increase = final_memory - initial_memory

      # Confirm memory usage increase is within reasonable range (under 100MB)
      expect(memory_increase).to be < 100_000 # In KB units

      # Confirm processing completed normally
      expect(result).to be_a(String)
      expect(result.length).to be > 0
    end
  end

  describe "Cross-browser compatibility simulation" do
    it "generates URLs that work across different environments" do
      editor_image = create(:editor_image, author: user, organization:)
      global_id = editor_image.file.blob.to_global_id.to_s

      # Test conversion from Global ID to Rails URL
      rails_url = Decidim::Cfj::UrlConverter.global_id_to_rails_url(global_id)

      expect(rails_url).to be_present
      expect(rails_url).to start_with("/rails/active_storage/blobs/")

      # Confirm URL is actually accessible (integration test level)
      # Note: Only validate URL format without making actual HTTP request
      expect(rails_url).to match(%r{^/rails/active_storage/blobs/redirect/[^/]+/.+})
    end
  end
end
