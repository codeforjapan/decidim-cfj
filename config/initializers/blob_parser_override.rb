# frozen_string_literal: true

require_relative "../../lib/decidim/cfj/signed_blob_token"

# Extends Decidim's BlobParser, which turns Active Storage URLs into Global IDs
# when rich text content is saved, with two cases it does not cover:
#
#   - S3 URLs, which production serves instead of the local disk service.
#   - URLs whose signature has expired. The parser verifies the signature
#     before looking the blob up, so an expired URL is left in the content
#     verbatim and is then dead for good: nothing converts it back afterwards,
#     and the URL itself no longer resolves. This happens whenever an editor is
#     open for longer than the URL's lifetime (ActiveStorage.urls_expire_in, 60
#     seconds in development) before being saved.
Rails.application.config.to_prepare do
  Decidim::ContentParsers::BlobParser # rubocop:disable Lint/Void

  module DecidimContentParsersBlobParserExpiredUrlsPatch
    S3_URL_REGEX = %r{
      https://
      [^/]+\.s3[^/]*\.amazonaws\.com/
      [^"'\s]+
    }x

    def rewrite
      replace_s3_urls(replace_expired_blobs(super))
    end

    private

    # Runs after super, so this only sees the URLs Decidim's own parser gave up
    # on - the ones it converted are Global IDs by now and no longer match.
    def replace_expired_blobs(text)
      text.gsub(Decidim::ContentParsers::BlobParser::BLOB_REGEX) do |match|
        captures = Regexp.last_match.named_captures
        blob = Decidim::Cfj::SignedBlobToken.blob_for(captures["type_part"], captures["key_part"])
        next match unless blob

        variation_key = generate_variation_key(captures["variation_part"]) if captures["type_part"].start_with?("representations")

        "#{blob.to_global_id}#{"/#{variation_key}" if variation_key}"
      end
    end

    def replace_s3_urls(text)
      text.gsub(S3_URL_REGEX) do |match|
        # Try to convert S3 URL to Global ID
        global_id = Decidim::Cfj::UrlConverter.s3_url_to_global_id(match)

        # If conversion successful, use Global ID; otherwise keep original URL
        global_id || match
      end
    end
  end

  Decidim::ContentParsers::BlobParser.prepend(DecidimContentParsersBlobParserExpiredUrlsPatch)
end
