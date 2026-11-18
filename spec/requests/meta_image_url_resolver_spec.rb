# frozen_string_literal: true

require "rails_helper"
require "decidim/blogs/test/factories"

# Covers config/initializers/meta_image_url_resolver_override.rb.
RSpec.describe "Meta image of a blog post" do
  let(:organization) { create(:organization) }
  let(:process) { create(:participatory_process, :published, organization:) }
  let(:component) { create(:post_component, :published, participatory_space: process) }
  let(:post_record) { create(:post, :published, component:, body: { en: %(<p>Body</p><img src="#{image_src}">) }) }
  let(:post_path) { "/#{organization.default_locale}/processes/#{process.slug}/f/#{component.id}/posts/#{post_record.id}" }
  let!(:pdf_blob) do
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new("%PDF-1.4"), filename: "document.pdf", content_type: "application/pdf")
  end
  let(:resolved_blob) { Decidim::MetaImageUrlResolver.new(post_record, organization).blob }

  before { host! organization.host }

  context "when an external image file name starts with the ID of another blob" do
    let(:image_src) { "https://images.example.org/#{pdf_blob.id}ba662b76f8a82e18.jpg" }

    it "does not pick the other blob" do
      expect(resolved_blob).not_to eq(pdf_blob)
    end

    it "renders the post" do
      get post_path

      expect(response).to have_http_status(:ok)
    end
  end

  context "when an uploaded image file name starts with the ID of another blob" do
    let(:image_blob) { create_file_blob(filename: "city.jpeg") }
    let(:image_src) do
      image_blob.update!(filename: "#{pdf_blob.id}city.jpeg")
      Rails.application.routes.url_helpers.rails_blob_path(image_blob, only_path: true)
    end

    it "picks the uploaded image" do
      expect(resolved_blob).to eq(image_blob)
    end
  end

  context "when the image is the GlobalID of a blob that cannot be resized" do
    let(:image_src) { pdf_blob.to_global_id.to_s }

    it "does not resolve a meta image" do
      expect(Decidim::MetaImageUrlResolver.new(post_record, organization).resolve).to be_nil
    end

    it "renders the post" do
      get post_path

      expect(response).to have_http_status(:ok)
    end
  end

  context "when the last segment of an external image URL is the ID of another blob" do
    let(:image_blob) { create_file_blob(filename: "city.jpeg") }
    let(:image_src) { "https://images.example.org/photos/#{image_blob.id}" }

    it "does not pick the other blob" do
      expect(resolved_blob).not_to eq(image_blob)
    end
  end

  context "when the image is the GlobalID of a blob" do
    let(:image_blob) { create_file_blob(filename: "city.jpeg") }
    let(:image_src) { image_blob.to_global_id.to_s }

    it "picks the blob" do
      expect(resolved_blob).to eq(image_blob)
    end
  end

  context "when the image is the GlobalID of a blob with a variation key" do
    let(:image_blob) { create_file_blob(filename: "city.jpeg") }
    let(:image_src) { "#{image_blob.to_global_id}/#{Base64.strict_encode64({ resize_to_limit: [100, 100] }.to_json)}" }

    it "picks the blob" do
      expect(resolved_blob).to eq(image_blob)
    end
  end
end
