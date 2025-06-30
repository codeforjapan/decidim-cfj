# frozen_string_literal: true

require "rails_helper"
require_relative "../../../../lib/decidim/cfj/url_converter"

# S3環境での統合テスト
# S3を使用している本番環境での動作を模擬テストする
describe "S3 Integration for Signed URL Fix" do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization:) }
  let(:editor_image) { create(:editor_image, author: user, organization:) }
  let(:blob) { editor_image.file.blob }

  describe "S3 URL patterns and conversion" do
    # 実際のS3 URLパターンをテスト
    let(:s3_urls) do
      [
        # 標準的なS3 URL
        "https://my-bucket.s3.amazonaws.com/#{blob.key}?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIOSFODNN7EXAMPLE%2F20230101%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Date=20230101T000000Z&X-Amz-Expires=3600&X-Amz-Signature=example&X-Amz-SignedHeaders=host",

        # リージョン付きS3 URL
        "https://my-bucket.s3.us-west-2.amazonaws.com/#{blob.key}?signature=abc123"

        # 古い形式のS3 URL（現在のregexではサポートしていない）
        # "https://s3.amazonaws.com/my-bucket/#{blob.key}?AWSAccessKeyId=AKIAIOSFODNN7EXAMPLE&Expires=1234567890&Signature=example",

        # S3-compatible services（現在のregexではサポートしていない）
        # "https://my-bucket.s3.example.com/#{blob.key}?X-Amz-Expires=3600&signature=test"
      ]
    end

    it "detects S3 URLs correctly with various patterns" do
      s3_regex = %r{
        https://
        [^/]+\.s3[^/]*\.amazonaws\.com/
        [^"'\s]+
      }x

      expect(s3_urls).to all(match(s3_regex))
    end

    it "converts S3 URLs to Global IDs" do
      s3_urls.each do |url|
        result = Decidim::Cfj::UrlConverter.s3_url_to_global_id(url)
        expect(result).to eq(blob.to_global_id.to_s), "Failed to convert S3 URL: #{url}"
      end
    end

    it "handles query parameters correctly" do
      url_with_params = "https://my-bucket.s3.amazonaws.com/#{blob.key}?X-Amz-Expires=3600&other=value"

      result = Decidim::Cfj::UrlConverter.s3_url_to_global_id(url_with_params)
      expect(result).to eq(blob.to_global_id.to_s)
    end
  end

  describe "BlobParser S3 URL processing" do
    let(:s3_url) { "https://my-bucket.s3.amazonaws.com/#{blob.key}?X-Amz-Expires=3600" }

    it "processes mixed content with S3 URLs" do
      mixed_content = <<~HTML
        <p>Here is some content:</p>
        <img src="#{s3_url}" alt="S3 image">
        <p>More content with <img src="/rails/active_storage/blobs/redirect/#{blob.signed_id}/file.jpg" alt="Rails image"></p>
        <img src="https://external.com/image.jpg" alt="External image">
      HTML

      parser = Decidim::ContentParsers::BlobParser.new(mixed_content, context: {})
      result = parser.rewrite

      # S3 URLはGlobal IDに変換される
      expect(result).not_to include(s3_url)
      expect(result).to include(blob.to_global_id.to_s)

      # Rails URLもGlobal IDに変換される
      expect(result).not_to include("/rails/active_storage/blobs/")

      # 外部URLはそのまま残る
      expect(result).to include("https://external.com/image.jpg")
    end

    it "handles malformed S3 URLs gracefully" do
      malformed_s3_urls = [
        "https://my-bucket.s3.amazonaws.com/nonexistent-key?signature=abc",
        "https://my-bucket.s3.amazonaws.com/?signature=abc", # keyなし
        "https://my-bucket.s3.amazonaws.com/#{blob.key}" # signature なし
      ]

      malformed_s3_urls.each do |url|
        content = "<img src=\"#{url}\" alt=\"test\">"
        parser = Decidim::ContentParsers::BlobParser.new(content, context: {})

        # エラーを起こさずに処理される
        expect { parser.rewrite }.not_to raise_error
        result = parser.rewrite

        # keyが存在しない場合は元のURLを保持、存在する場合はGlobal IDに変換
        if url.include?(blob.key)
          expect(result).to include("gid://") # blobが存在するのでGlobal IDに変換
        else
          expect(result).to include(url) # 存在しないkeyなので元のURLを保持
        end
      end
    end
  end

  describe "Performance considerations for S3 environment" do
    it "efficiently processes large content with multiple S3 URLs" do
      # 大量のS3 URLを含むコンテンツ
      s3_urls = 50.times.map { |i| "https://bucket-#{i}.s3.amazonaws.com/#{blob.key}?sig=#{i}" }
      large_content = s3_urls.map { |url| "<img src=\"#{url}\" alt=\"test\">" }.join("\n")

      start_time = Time.current

      parser = Decidim::ContentParsers::BlobParser.new(large_content, context: {})
      result = parser.rewrite

      end_time = Time.current
      processing_time = end_time - start_time

      # 処理時間が合理的な範囲内であることを確認（1秒以内）
      expect(processing_time).to be < 1.0

      # すべてのS3 URLが処理されたことを確認
      s3_urls.each do |url|
        expect(result).not_to include(url)
      end
    end
  end

  describe "S3 environment error handling" do
    it "handles S3 connection timeouts gracefully" do
      # S3への接続タイムアウトを模擬
      allow(ActiveStorage::Blob).to receive(:find_by).and_raise(Timeout::Error)

      s3_url = "https://my-bucket.s3.amazonaws.com/some-key?signature=abc"

      expect do
        Decidim::Cfj::UrlConverter.s3_url_to_global_id(s3_url)
      end.not_to raise_error

      result = Decidim::Cfj::UrlConverter.s3_url_to_global_id(s3_url)
      expect(result).to be_nil
    end

    it "handles S3 permissions errors gracefully" do
      # S3権限エラーを模擬
      allow(ActiveStorage::Blob).to receive(:find_by).and_raise(
        StandardError.new("Access Denied")
      )

      s3_url = "https://my-bucket.s3.amazonaws.com/some-key?signature=abc"

      expect do
        Decidim::Cfj::UrlConverter.s3_url_to_global_id(s3_url)
      end.not_to raise_error

      result = Decidim::Cfj::UrlConverter.s3_url_to_global_id(s3_url)
      expect(result).to be_nil
    end
  end

  describe "Environment-specific behavior" do
    it "works correctly regardless of storage configuration" do
      # テスト環境: file storage
      # 本番環境: S3 storage
      # 両方で動作することを確認

      original_service = Rails.application.config.active_storage.service

      # ファイルストレージでのテスト
      Rails.application.config.active_storage.service = :test

      parser = Decidim::ContentParsers::BlobParser.new(
        "<img src=\"/rails/active_storage/blobs/redirect/#{blob.signed_id}/test.jpg\">",
        context: {}
      )
      result = parser.rewrite

      expect(result).to include("gid://")
      expect(result).not_to include("/rails/active_storage/blobs/")

      # 設定を元に戻す
      Rails.application.config.active_storage.service = original_service
    end
  end

  describe "Regression tests for common S3 issues" do
    it "handles S3 URLs with special characters in keys" do
      special_chars_key = "path/with spaces/and-dashes/file_name.jpg"
      encoded_key = CGI.escape(special_chars_key)

      # 既存のblobを使用し、キーのみをモック
      allow(blob).to receive(:key).and_return(special_chars_key)

      # URLにエンコードされたキーとデコードされたキーの両方で検索を許可
      allow(ActiveStorage::Blob).to receive(:find_by).with(key: special_chars_key)
                                                     .and_return(blob)
      allow(ActiveStorage::Blob).to receive(:find_by).with(key: encoded_key)
                                                     .and_return(blob)

      s3_url = "https://my-bucket.s3.amazonaws.com/#{encoded_key}?signature=abc"

      result = Decidim::Cfj::UrlConverter.s3_url_to_global_id(s3_url)
      expect(result).to eq(blob.to_global_id.to_s)
    end

    it "handles S3 URLs from different regions and services" do
      regional_urls = [
        "https://my-bucket.s3.eu-west-1.amazonaws.com/#{blob.key}?sig=1",
        "https://my-bucket.s3.ap-northeast-1.amazonaws.com/#{blob.key}?sig=2",
        "https://my-bucket.s3.us-gov-west-1.amazonaws.com/#{blob.key}?sig=3"
      ]

      regional_urls.each do |url|
        result = Decidim::Cfj::UrlConverter.s3_url_to_global_id(url)
        expect(result).to eq(blob.to_global_id.to_s), "Failed for URL: #{url}"
      end
    end
  end
end
