# frozen_string_literal: true

require "rails_helper"

# Covers config/initializers/blob_parser_override.rb.
#
# Decidim stores rich text images as Global IDs, converting the URLs on save
# with BlobParser. That conversion verifies the URL's signature first, so an
# expired URL used to be written to the database verbatim - and since nothing
# converts it afterwards and the URL itself no longer resolves, the image was
# dead for good. An editor left open longer than ActiveStorage.urls_expire_in
# (60 seconds in development) is enough to hit it.
describe "BlobParser with expired Active Storage URLs" do
  let(:blob) { create(:blob, :image) }
  let(:parser) { Decidim::ContentParsers::BlobParser.new(%(<img src="#{url}">), {}) }

  def disk_token(expires_in:)
    ActiveStorage.verifier.generate(
      { key: blob.key, disposition: "inline", content_type: blob.content_type, service_name: "local" },
      expires_in:,
      purpose: :blob_key
    )
  end

  context "when the blob URL's signature is still valid" do
    let(:url) { Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true) }

    it "converts it to a Global ID" do
      expect(parser.rewrite).to include(blob.to_global_id.to_s)
    end
  end

  context "when the blob URL's signature has expired" do
    let(:url) { "/rails/active_storage/blobs/redirect/#{blob.signed_id(expires_in: -1.second)}/#{blob.filename}" }

    it "still converts it to a Global ID" do
      expect(parser.rewrite).to include(blob.to_global_id.to_s)
      expect(parser.rewrite).not_to include("/rails/active_storage/")
    end
  end

  context "when a disk service URL has expired" do
    let(:url) { "/rails/active_storage/disk/#{disk_token(expires_in: -1.second)}/#{blob.filename}" }

    it "still converts it to a Global ID" do
      expect(parser.rewrite).to include(blob.to_global_id.to_s)
    end
  end

  context "when a representation URL has expired" do
    let(:variant) { blob.variant(resize_to_limit: [100, 100]) }
    let(:url) do
      "/rails/active_storage/representations/redirect/" \
        "#{blob.signed_id(expires_in: -1.second)}/#{variant.variation.key}/#{blob.filename}"
    end

    it "converts it to a Global ID that keeps the variation" do
      rewritten = parser.rewrite

      expect(rewritten).to include(blob.to_global_id.to_s)
      # Same shape Decidim's own parser produces for a non-expired one.
      expect(rewritten).to match(%r{gid://[^/]+/ActiveStorage::Blob/#{blob.id}/[\w=-]+})
    end
  end

  context "when the signature does not verify" do
    let(:url) { "/rails/active_storage/blobs/redirect/#{blob.signed_id(expires_in: -1.second).sub(/.$/, "x")}/#{blob.filename}" }

    # Only the expiry is disregarded, never the signature: a forged token must
    # not be able to point saved content at an arbitrary blob.
    it "leaves the URL alone" do
      expect(parser.rewrite).not_to include("gid://")
    end
  end

  context "when the token is authentic but for another purpose" do
    let(:url) { "/rails/active_storage/disk/#{blob.signed_id(expires_in: -1.second)}/#{blob.filename}" }

    it "leaves the URL alone" do
      expect(parser.rewrite).not_to include("gid://")
    end
  end

  context "when the blob no longer exists" do
    let(:url) { "/rails/active_storage/blobs/redirect/#{blob.signed_id(expires_in: -1.second)}/#{blob.filename}" }

    it "leaves the URL alone" do
      signed_url = url
      blob.destroy
      parser = Decidim::ContentParsers::BlobParser.new(%(<img src="#{signed_url}">), {})

      expect(parser.rewrite).not_to include("gid://")
    end
  end

  describe "the round trip a saved image actually takes" do
    let(:url) { "/rails/active_storage/blobs/redirect/#{blob.signed_id(expires_in: -1.second)}/#{blob.filename}" }

    it "survives an editor that was open past the URL's lifetime" do
      stored = Decidim::Attributes::RichText.new.send(:serialize_value, %(<p>text</p><img src="#{url}">))
      expect(stored).to include(blob.to_global_id.to_s)

      # What the public page then renders from it.
      rendered = Decidim::ContentRenderers::BlobRenderer.new(stored).render
      expect(rendered).to include("/rails/active_storage/")
      expect(rendered).not_to include("gid://")
    end
  end
end
