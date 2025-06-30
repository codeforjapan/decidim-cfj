# frozen_string_literal: true

require "uri"
require "cgi"
require "base64"
require "json"

module Decidim
  module Cfj
    # Utility class to convert between different URL formats for Active Storage blobs
    class UrlConverter
      class << self
        # Convert Rails blob URL to Global ID
        # @param rails_url [String] Rails blob URL like "/rails/active_storage/blobs/redirect/..."
        # @return [String, nil] Global ID like "gid://app-name/ActiveStorage::Blob/123" or nil if conversion fails
        def rails_url_to_global_id(rails_url)
          return nil unless rails_url.is_a?(String)
          return nil unless rails_url.include?("/rails/active_storage/blobs/")

          blob_id = extract_blob_id_from_rails_url(rails_url)
          return nil unless blob_id

          begin
            blob = ActiveStorage::Blob.find(blob_id)
            blob.to_global_id.to_s
          rescue ActiveRecord::RecordNotFound
            nil
          end
        end

        # Convert S3 URL to Global ID by finding matching blob
        # @param s3_url [String] S3 URL like "https://bucket.s3.region.amazonaws.com/path?signature=..."
        # @return [String, nil] Global ID or nil if no matching blob found
        def s3_url_to_global_id(s3_url)
          return nil unless s3_url.is_a?(String)
          return nil unless s3_url.include?("s3") && s3_url.include?("amazonaws.com")

          # Extract key from S3 URL (this is the tricky part)
          key = extract_key_from_s3_url(s3_url)
          return nil unless key

          # Find blob by key
          begin
            blob = ActiveStorage::Blob.find_by(key:)
            if blob
              blob.to_global_id.to_s
            else
              Rails.logger.warn "Blob not found for S3 key: #{key}. URL: #{s3_url[0..100]}..."
              nil
            end
          rescue StandardError => e
            Rails.logger.warn "Failed to find blob by key #{key}: #{e.message}"
            nil
          end
        end

        # Try to find blob by filename when key search fails
        # @param s3_url [String] S3 URL
        # @return [String, nil] Global ID or nil if no matching blob found
        def s3_url_to_global_id_by_filename(s3_url)
          return nil unless s3_url.is_a?(String)

          # Extract filename from query parameters
          filename = extract_filename_from_s3_url(s3_url)
          return nil unless filename

          # Search for blobs with matching filename
          begin
            blobs = ActiveStorage::Blob.where(filename:)
            case blobs.count
            when 0
              Rails.logger.warn "No blob found with filename: #{filename}"
              nil
            when 1
              blobs.first.to_global_id.to_s
            else
              Rails.logger.warn "Multiple blobs found with filename #{filename}, using the most recent"
              blobs.order(created_at: :desc).first.to_global_id.to_s
            end
          rescue StandardError => e
            Rails.logger.warn "Failed to find blob by filename #{filename}: #{e.message}"
            nil
          end
        end

        # Convert any blob URL (Rails or S3) to Global ID
        # @param url [String] Any blob URL
        # @return [String, nil] Global ID or nil if conversion fails
        def url_to_global_id(url)
          return nil unless url.is_a?(String)

          if url.include?("/rails/active_storage/blobs/")
            rails_url_to_global_id(url)
          elsif url.include?("s3") && url.include?("amazonaws.com")
            s3_url_to_global_id(url)
          end
        end

        # Convert Global ID to permanent Rails URL
        # @param global_id [String] Global ID like "gid://app-name/ActiveStorage::Blob/123"
        # @return [String, nil] Permanent Rails URL or nil if conversion fails
        def global_id_to_rails_url(global_id)
          return nil unless global_id.is_a?(String)
          return nil unless global_id.start_with?("gid://")

          begin
            blob = GlobalID::Locator.locate(global_id)
            return nil unless blob.is_a?(ActiveStorage::Blob)

            Rails.application.routes.url_helpers.rails_blob_url(blob, only_path: true)
          rescue StandardError => e
            Rails.logger.warn "Failed to locate blob from global_id #{global_id}: #{e.message}"
            nil
          end
        end

        # Extract key from S3 URL (public method for testing)
        # @param s3_url [String] S3 URL
        # @return [String, nil] Active Storage key or nil if extraction fails
        def extract_key_from_s3_url(s3_url)
          uri = URI.parse(s3_url)

          # S3 URLs typically have the format:
          # https://bucket.s3.region.amazonaws.com/key?signature_params
          # or
          # https://s3.region.amazonaws.com/bucket/key?signature_params

          path = uri.path
          return nil if path.blank?

          # Remove leading slash
          path = path[1..-1] if path.start_with?("/")

          # For subdomain format: bucket.s3.region.amazonaws.com/key
          if uri.host.include?(".s3.")
            # The path is the key
            path
          else
            # For path format: s3.region.amazonaws.com/bucket/key
            # Skip the bucket name (first path component)
            path_parts = path.split("/", 2)
            path_parts.length > 1 ? path_parts[1] : nil
          end
        rescue URI::InvalidURIError => e
          Rails.logger.warn "Invalid S3 URL: #{s3_url}, error: #{e.message}"
          nil
        rescue StandardError => e
          Rails.logger.warn "Failed to extract key from S3 URL: #{e.message}"
          nil
        end

        # Extract filename from S3 URL query parameters (public method for testing)
        # @param s3_url [String] S3 URL
        # @return [String, nil] Filename or nil if not found
        def extract_filename_from_s3_url(s3_url)
          uri = URI.parse(s3_url)
          query_params = CGI.parse(uri.query || "")

          # Look for response-content-disposition parameter
          disposition = query_params["response-content-disposition"]&.first
          return nil unless disposition

          # Extract filename from disposition header
          # Format: inline; filename="test-image.jpg"
          match = disposition.match(/filename[*]?=['"]([^'"]+)['"]/)
          match ? match[1] : nil
        rescue StandardError => e
          Rails.logger.warn "Failed to extract filename from S3 URL: #{e.message}"
          nil
        end

        private

        # Extract blob ID from Rails blob URL
        # @param rails_url [String] Rails blob URL
        # @return [Integer, nil] Blob ID or nil if extraction fails
        def extract_blob_id_from_rails_url(rails_url)
          # Parse URL: /rails/active_storage/blobs/redirect/SIGNED_TOKEN/filename
          parts = rails_url.split("/")
          return nil unless parts.length >= 6

          signed_token = parts[5]

          begin
            # Use ActiveStorage's built-in method to find blob from signed token
            blob = ActiveStorage::Blob.find_signed(signed_token)
            blob&.id
          rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound => e
            Rails.logger.warn "Failed to extract blob ID from Rails URL: #{e.message}"
            nil
          end
        end
      end
    end
  end
end
