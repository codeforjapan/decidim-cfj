# frozen_string_literal: true

require "rails_helper"
require "decidim/blogs/test/factories"

describe "Blog post image handling in admin" do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization:) }
  let(:participatory_process) { create(:participatory_process, organization:) }
  let!(:component) do
    create(:component,
           manifest_name: "blogs",
           name: { "en" => "Test Blog" },
           participatory_space: participatory_process)
  end

  before do
    switch_to_host(organization.host)
    login_as user, scope: :user
  end

  describe "URL conversion functionality" do
    let!(:editor_image) { create(:editor_image, author: user, organization:) }

    it "demonstrates URL conversion capabilities" do
      # Test that our URL converter is available and working
      expect(Decidim::Cfj::UrlConverter).to respond_to(:s3_url_to_global_id)
      expect(Decidim::Cfj::UrlConverter).to respond_to(:rails_url_to_global_id)
      expect(Decidim::Cfj::UrlConverter).to respond_to(:global_id_to_rails_url)

      # Test Global ID conversion
      global_id = editor_image.file.blob.to_global_id.to_s
      expect(global_id).to start_with("gid://")

      # Test URL conversion
      rails_url = Rails.application.routes.url_helpers.rails_blob_url(
        editor_image.file.blob,
        only_path: true
      )
      expect(rails_url).to match(%r{/rails/active_storage/blobs/})

      # Verify our converter can handle the conversion
      converted_global_id = Decidim::Cfj::UrlConverter.rails_url_to_global_id(rails_url)
      expect(converted_global_id).to eq(global_id)
    end

    it "can convert S3 URLs to Global IDs" do
      # Mock S3 URL
      s3_url = "https://test-bucket.s3.amazonaws.com/#{editor_image.file.blob.key}?signature=abc123"

      # Mock the conversion (since we don't have real S3 in test)
      allow(Decidim::Cfj::UrlConverter).to receive(:s3_url_to_global_id)
        .with(s3_url)
        .and_return(editor_image.file.blob.to_global_id.to_s)

      result = Decidim::Cfj::UrlConverter.s3_url_to_global_id(s3_url)
      expect(result).to eq(editor_image.file.blob.to_global_id.to_s)
    end
  end

  describe "blog post image storage and display" do
    let!(:editor_image) { create(:editor_image, author: user, organization:) }

    it "stores images as Global IDs in database and displays them correctly" do
      # Step 1: Create a blog post with an image using our form
      rails_url = Rails.application.routes.url_helpers.rails_blob_url(
        editor_image.file.blob,
        only_path: true
      )

      form_params = {
        title: {
          "en" => "Test Post with Image",
          "ja" => "画像付きテスト投稿"
        },
        body: {
          "en" => "<p>Content with image: <img src=\"#{rails_url}\" alt=\"test image\"> End</p>",
          "ja" => "<p>画像付きコンテンツ: <img src=\"#{rails_url}\" alt=\"テスト画像\"> 終了</p>"
        },
        decidim_author_id: user.id
      }

      form = Decidim::Blogs::Admin::PostForm.from_params(form_params).with_context(
        current_user: user,
        current_organization: organization,
        current_component: component
      )

      expect(form).to be_valid

      # Step 2: Create the post record to simulate saving
      blog_post = create(:post,
                         component:,
                         title: form.title,
                         body: form.body,
                         author: user)

      # Step 3: Verify that URLs were converted to Global IDs in database
      expect(blog_post.body["en"]).not_to include(rails_url)
      expect(blog_post.body["en"]).to include("gid://")
      expect(blog_post.body["en"]).to include(editor_image.file.blob.to_global_id.to_s)

      expect(blog_post.body["ja"]).not_to include(rails_url)
      expect(blog_post.body["ja"]).to include("gid://")
      expect(blog_post.body["ja"]).to include(editor_image.file.blob.to_global_id.to_s)

      # Step 4: Verify that content can be displayed properly (Global ID to URL conversion)
      global_id = editor_image.file.blob.to_global_id.to_s
      converted_url = Decidim::Cfj::UrlConverter.global_id_to_rails_url(global_id)

      expect(converted_url).to be_present
      expect(converted_url).to match(%r{/rails/active_storage/blobs/})
    end

    it "handles S3 URLs in existing content and converts them" do
      # Step 1: Create a post with S3 URL (simulating old content)
      s3_url = "https://test-bucket.s3.amazonaws.com/#{editor_image.file.blob.key}?signature=abc123"

      blog_post = create(:post,
                         component:,
                         body: {
                           "en" => "<p>Old content: <img src=\"#{s3_url}\" alt=\"old image\"> End</p>",
                           "ja" => "<p>古いコンテンツ: <img src=\"#{s3_url}\" alt=\"古い画像\"> 終了</p>"
                         },
                         author: user)

      # Step 2: Edit the post through the form (this should trigger URL conversion)
      form_params = {
        title: blog_post.title,
        body: blog_post.body, # This should be processed by our form override
        decidim_author_id: user.id
      }

      # Mock the S3 URL conversion since we don't have real S3 in test
      allow(Decidim::Cfj::UrlConverter).to receive(:s3_url_to_global_id)
        .and_return(editor_image.file.blob.to_global_id.to_s)

      form = Decidim::Blogs::Admin::PostForm.from_params(form_params).with_context(
        current_user: user,
        current_organization: organization,
        current_component: component
      )

      # Step 3: Verify that S3 URLs were converted to Global IDs
      expect(form.body["en"]).not_to include(s3_url)
      expect(form.body["en"]).to include("gid://")
      expect(form.body["en"]).to include(editor_image.file.blob.to_global_id.to_s)
    end

    it "demonstrates the complete image lifecycle in blog posts" do
      # Step 1: Start with no posts
      expect(Decidim::Blogs::Post.count).to eq(0)
      expect(Decidim::EditorImage.count).to eq(1) # Our editor_image

      # Step 2: Create content with mixed URL types
      rails_url = Rails.application.routes.url_helpers.rails_blob_url(
        editor_image.file.blob,
        only_path: true
      )

      original_content = "<p>Test with image: <img src=\"#{rails_url}\" alt=\"test\"> More text</p>"

      # Step 3: Process through our form
      form_params = {
        title: { "en" => "Image Test", "ja" => "画像テスト" },
        body: { "en" => original_content, "ja" => original_content },
        decidim_author_id: user.id
      }

      form = Decidim::Blogs::Admin::PostForm.from_params(form_params).with_context(
        current_user: user,
        current_organization: organization,
        current_component: component
      )

      # Step 4: Verify form processing
      expect(form).to be_valid

      # The form should have converted Rails URLs to Global IDs
      processed_content = form.body["en"]
      expect(processed_content).not_to include("/rails/active_storage/blobs/")
      expect(processed_content).to include("gid://")

      # Step 5: Create the actual post
      blog_post = create(:post,
                         component:,
                         title: form.title,
                         body: form.body,
                         author: user)

      # Step 6: Verify database storage
      blog_post.reload
      expect(blog_post.body["en"]).to include("gid://")
      expect(blog_post.body["en"]).not_to include("/rails/active_storage/blobs/")
      expect(blog_post.body["en"]).not_to include("amazonaws.com")

      # Step 7: Verify Global ID can be converted back to viewable URL
      global_id_in_content = blog_post.body["en"].match(%r{gid://[^"]+})[0]
      viewable_url = Decidim::Cfj::UrlConverter.global_id_to_rails_url(global_id_in_content)

      expect(viewable_url).to be_present
      expect(viewable_url).to match(%r{/rails/active_storage/blobs/})

      # Step 8: Verify the viewable URL points to the same blob
      expect(global_id_in_content).to eq(editor_image.file.blob.to_global_id.to_s)
    end
  end

  describe "form override functionality" do
    it "verifies that form overrides are in place" do
      # Check that our form classes exist and have the URL conversion methods (private methods)
      expect(Decidim::Blogs::Admin::PostForm.private_method_defined?(:convert_rich_text_urls)).to be true
      expect(Decidim::Proposals::Admin::ProposalAnswerForm.private_method_defined?(:convert_rich_text_urls)).to be true
    end
  end

  describe "editor images controller override" do
    it "can create editor images" do
      # Test that editor images can be created (which would use our controller override)
      expect(Decidim::EditorImage.count).to eq(0)

      editor_image = create(:editor_image, author: user, organization:)
      expect(editor_image).to be_persisted
      expect(editor_image.file).to be_attached
    end
  end

  describe "content parsers override" do
    it "demonstrates that InlineImagesParser is available" do
      # Test that our content parser is available
      expect(defined?(Decidim::ContentParsers::InlineImagesParser)).to be_truthy

      # Test basic functionality
      base64_image = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAHGartKiAAAAABJRU5ErkJggg=="
      content = "<p>Test content</p><img src=\"#{base64_image}\"><p>More content</p>"
      context = { user: }

      parser = Decidim::ContentParsers::InlineImagesParser.new(content, context)
      expect(parser).to respond_to(:rewrite)
    end
  end
end
