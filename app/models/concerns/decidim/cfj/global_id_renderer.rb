# frozen_string_literal: true

module Decidim
  module Cfj
    # Concern to render Global IDs instead of blob URLs in rich text content
    module GlobalIdRenderer
      extend ActiveSupport::Concern

      included do
        # Override getter methods for rich text fields to return Global IDs
        def render_with_global_ids(attribute_name)
          content = public_send("#{attribute_name}_without_global_ids")
          return content if content.blank?

          # Convert blob URLs to Global IDs in the content
          convert_urls_to_global_ids(content)
        end

        private

        # Convert various URL formats to Global IDs
        def convert_urls_to_global_ids(content)
          return content unless content.is_a?(Hash)

          content.transform_values do |text|
            next text if text.blank?

            # Pattern to match Rails blob URLs
            text = text.gsub(%r{/rails/active_storage/blobs/[^"'\s]+}) do |match|
              Decidim::Cfj::UrlConverter.rails_url_to_global_id(match) || match
            end

            # Pattern to match S3 URLs
            text = text.gsub(%r{https://[^/]+\.s3[^/]*\.amazonaws\.com/[^?"'\s]+}) do |match|
              Decidim::Cfj::UrlConverter.s3_url_to_global_id(match) || match
            end

            text
          end
        end
      end
    end
  end
end
