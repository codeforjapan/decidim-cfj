# frozen_string_literal: true

require "rails_helper"
require_relative "../../../../lib/decidim/cfj/url_converter"

# Edge cases and robustness tests
describe "UrlConverter Edge Cases and Robustness" do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization:) }
  let(:editor_image) { create(:editor_image, author: user, organization:) }
  let(:blob) { editor_image.file.blob }

  describe "Malformed input handling" do
    it "gracefully handles malformed URLs" do
      malformed_urls = [
        nil,
        "",
        "not-a-url",
        "https://",
        "https://example.com",
        "https://s3.amazonaws.com", # S3 domain but no path
        "https://my-bucket.s3.amazonaws.com/", # No key
        "https://my-bucket.s3.amazonaws.com/?", # Empty query
        "ftp://my-bucket.s3.amazonaws.com/key", # Wrong protocol
        "https://my-bucket.s2.amazonaws.com/key", # Wrong service name
        "javascript:alert('xss')", # XSS attempt
        "<script>alert('xss')</script>" # HTML tag
      ]

      malformed_urls.each do |url|
        expect do
          result = Decidim::Cfj::UrlConverter.s3_url_to_global_id(url)
          expect(result).to be_nil, "Should return nil for malformed URL: #{url.inspect}"
        end.not_to raise_error, "Should not raise error for: #{url.inspect}"
      end
    end

    it "handles very long URLs" do
      # Handle very long URLs
      very_long_key = "a" * 1000
      long_url = "https://my-bucket.s3.amazonaws.com/#{very_long_key}?signature=#{"b" * 1000}"

      expect do
        result = Decidim::Cfj::UrlConverter.s3_url_to_global_id(long_url)
        expect(result).to be_nil # Returns nil for non-existent key
      end.not_to raise_error
    end

    it "handles URLs with unicode characters" do
      unicode_urls = [
        "https://my-bucket.s3.amazonaws.com/ファイル名.jpg?signature=test",
        "https://my-bucket.s3.amazonaws.com/файл.jpg?signature=test",
        "https://my-bucket.s3.amazonaws.com/文件.jpg?signature=test",
        "https://my-bucket.s3.amazonaws.com/🖼️.jpg?signature=test"
      ]

      unicode_urls.each do |url|
        expect do
          result = Decidim::Cfj::UrlConverter.s3_url_to_global_id(url)
          # Returns nil for non-existent file
          expect(result).to be_nil
        end.not_to raise_error, "Should handle unicode URL: #{url}"
      end
    end
  end

  describe "Security considerations" do
    it "prevents URL injection attacks" do
      # Attempt URL injection
      malicious_inputs = [
        "https://my-bucket.s3.amazonaws.com/file.jpg?signature=test\"><script>alert('xss')</script>",
        "https://my-bucket.s3.amazonaws.com/file.jpg?signature=test&redirect=http://evil.com",
        "https://my-bucket.s3.amazonaws.com/file.jpg?signature=test\nLocation: http://evil.com",
        "https://my-bucket.s3.amazonaws.com/file.jpg?signature=test%0ALocation:%20http://evil.com"
      ]

      malicious_inputs.each do |input|
        expect do
          result = Decidim::Cfj::UrlConverter.s3_url_to_global_id(input)
          expect(result).to be_nil
        end.not_to raise_error, "Should safely handle malicious input: #{input}"
      end
    end

    it "validates Global ID format in reverse conversion" do
      invalid_global_ids = [
        nil,
        "",
        "not-a-global-id",
        "gid://",
        "gid://app/",
        "gid://app/Model/",
        "gid://app/Model/abc", # Non-numeric ID
        "javascript:alert('xss')",
        "<script>alert('xss')</script>",
        "gid://evil-app/EvilModel/123" # GID from different app
      ]

      invalid_global_ids.each do |gid|
        expect do
          result = Decidim::Cfj::UrlConverter.global_id_to_rails_url(gid)
          expect(result).to be_nil, "Should return nil for invalid GID: #{gid.inspect}"
        end.not_to raise_error, "Should handle invalid GID safely: #{gid.inspect}"
      end
    end
  end

  describe "Error boundary testing" do
    it "handles ActiveRecord errors gracefully" do
      s3_url = "https://my-bucket.s3.amazonaws.com/#{blob.key}?signature=test"

      # Mock various ActiveRecord errors
      errors_to_test = [
        ActiveRecord::RecordNotFound,
        ActiveRecord::ConnectionTimeoutError,
        ActiveRecord::StatementInvalid,
        ActiveRecord::DatabaseConfigurations::InvalidConfigurationError
      ]

      errors_to_test.each do |error_class|
        allow(ActiveStorage::Blob).to receive(:find_by).and_raise(error_class)

        expect do
          result = Decidim::Cfj::UrlConverter.s3_url_to_global_id(s3_url)
          expect(result).to be_nil
        end.not_to raise_error, "Should handle #{error_class} gracefully"
      end
    end
  end
end
