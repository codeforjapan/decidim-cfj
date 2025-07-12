# frozen_string_literal: true

# Override Decidim's BlobParser to also handle S3 URLs
# This ensures that S3 URLs are converted to Global IDs when content is saved

Rails.application.config.to_prepare do
  # Extend the existing BlobParser with S3 URL handling
  Decidim::ContentParsers::BlobParser.class_eval do
    # Add S3 URL pattern to match S3 URLs
    S3_URL_REGEX = %r{
      https://
      [^/]+\.s3[^/]*\.amazonaws\.com/
      [^"'\s]+
    }x

    # Store original rewrite method
    alias_method :original_rewrite, :rewrite unless method_defined?(:original_rewrite)

    def rewrite
      # First, run the original blob replacement
      content_after_blobs = original_rewrite

      # Then, replace S3 URLs
      replace_s3_urls(content_after_blobs)
    end

    private

    def replace_s3_urls(text)
      text.gsub(S3_URL_REGEX) do |match|
        # Try to convert S3 URL to Global ID
        global_id = Decidim::Cfj::UrlConverter.s3_url_to_global_id(match)

        # If conversion successful, use Global ID; otherwise keep original URL
        global_id || match
      end
    end
  end
end
