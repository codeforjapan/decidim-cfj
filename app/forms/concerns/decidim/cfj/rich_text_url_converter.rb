# frozen_string_literal: true

module Decidim
  module Cfj
    # Shared concern for converting URLs in rich text fields to Global IDs
    module RichTextUrlConverter
      extend ActiveSupport::Concern

      private

      # Convert URLs in rich text content to Global IDs
      def convert_rich_text_urls(value)
        return value if value.blank?

        case value
        when Hash
          # For multilingual fields
          value.transform_values { |text| convert_text_urls(text) }
        when String
          # For single language fields
          convert_text_urls(value)
        else
          value
        end
      end

      # Convert various URL formats to Global IDs in text
      def convert_text_urls(text)
        return text if text.blank?

        # Convert Rails blob URLs to Global IDs
        text = text.gsub(%r{/rails/active_storage/blobs/[^"'\s]+}) do |match|
          Decidim::Cfj::UrlConverter.rails_url_to_global_id(match) || match
        end

        # Convert S3 URLs to Global IDs
        text.gsub(%r{https://[^/]+\.s3[^/]*\.amazonaws\.com/[^?"'\s]+}) do |match|
          Decidim::Cfj::UrlConverter.s3_url_to_global_id(match) || match
        end
      end
    end
  end
end