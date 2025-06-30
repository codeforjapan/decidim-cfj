# frozen_string_literal: true

require "rails_helper"
require_relative "../../../../lib/decidim/cfj/url_converter"

# 本番環境での実用性に焦点を当てたテスト
describe "S3 Production Readiness" do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization:) }
  let(:editor_image) { create(:editor_image, author: user, organization:) }
  let(:blob) { editor_image.file.blob }

  describe "Standard S3 URL patterns" do
    it "handles typical S3 URLs from AWS" do
      # AWS S3で実際に生成される典型的なURL形式をテスト
      typical_s3_urls = [
        "https://my-bucket.s3.amazonaws.com/#{blob.key}?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Expires=3600",
        "https://my-bucket.s3.us-west-2.amazonaws.com/#{blob.key}?signature=abc123",
        "https://my-bucket.s3.ap-northeast-1.amazonaws.com/#{blob.key}?X-Amz-Expires=7200"
      ]

      typical_s3_urls.each do |url|
        result = Decidim::Cfj::UrlConverter.s3_url_to_global_id(url)
        expect(result).to eq(blob.to_global_id.to_s), "Failed to convert: #{url}"
      end
    end

    it "correctly identifies S3 URLs with current regex" do
      # 現在のBlobParserで使用されているregexと同じパターンでテスト
      s3_regex = %r{
        https://
        [^/]+\.s3[^/]*\.amazonaws\.com/
        [^"'\s]+
      }x

      valid_urls = [
        "https://my-bucket.s3.amazonaws.com/#{blob.key}?signature=test",
        "https://my-bucket.s3.us-west-2.amazonaws.com/#{blob.key}?X-Amz-Expires=3600"
      ]

      expect(valid_urls).to all(match(s3_regex))
    end
  end

  describe "BlobParser integration with real content" do
    it "processes typical admin content with S3 URLs" do
      # 実際の管理画面で作成されそうなコンテンツ
      s3_url = "https://my-bucket.s3.amazonaws.com/#{blob.key}?X-Amz-Expires=3600"

      real_world_content = <<~HTML
        <h2>お知らせ</h2>
        <p>新しいサービスについてお知らせします。</p>
        <p><img src="#{s3_url}" alt="サービス画像" style="width: 100%;"></p>
        <p>詳細については<a href="/info">こちら</a>をご覧ください。</p>
      HTML

      parser = Decidim::ContentParsers::BlobParser.new(real_world_content, context: {})
      result = parser.rewrite

      # S3 URLがGlobal IDに変換されていることを確認
      expect(result).not_to include("s3.amazonaws.com")
      expect(result).to include(blob.to_global_id.to_s)

      # その他のコンテンツは保持されていることを確認
      expect(result).to include("お知らせ")
      expect(result).to include('href="/info"')
      expect(result).to include('style="width: 100%;"')
    end
  end

  describe "Error handling in production scenarios" do
    it "handles non-existent blob keys gracefully" do
      non_existent_url = "https://my-bucket.s3.amazonaws.com/non-existent-key-12345?signature=test"

      expect do
        result = Decidim::Cfj::UrlConverter.s3_url_to_global_id(non_existent_url)
        expect(result).to be_nil
      end.not_to raise_error
    end

    it "handles database connection issues during URL conversion" do
      s3_url = "https://my-bucket.s3.amazonaws.com/#{blob.key}?signature=test"

      # データベース接続エラーを模擬
      allow(ActiveStorage::Blob).to receive(:find_by).and_raise(ActiveRecord::ConnectionTimeoutError)

      expect do
        result = Decidim::Cfj::UrlConverter.s3_url_to_global_id(s3_url)
        expect(result).to be_nil
      end.not_to raise_error
    end
  end

  describe "Performance characteristics" do
    it "processes multiple S3 URLs efficiently" do
      # 実際のブログ投稿で考えられる画像数（5-10個）でテスト
      s3_urls = 8.times.map { |i| "https://bucket-#{i}.s3.amazonaws.com/#{blob.key}?sig=#{i}" }
      content_with_multiple_images = s3_urls.map { |url| "<img src=\"#{url}\" alt=\"image\">" }.join("\n")

      start_time = Time.current
      parser = Decidim::ContentParsers::BlobParser.new(content_with_multiple_images, context: {})
      result = parser.rewrite
      end_time = Time.current

      processing_time = end_time - start_time

      # 8個の画像処理が0.5秒以内で完了することを確認
      expect(processing_time).to be < 0.5

      # すべてのS3 URLが変換されていることを確認
      s3_urls.each do |url|
        expect(result).not_to include(url)
      end
      expect(result.scan("gid://").length).to eq(8)
    end
  end

  describe "Security validation" do
    it "safely handles potentially malicious S3 URLs" do
      malicious_attempts = [
        "https://my-bucket.s3.amazonaws.com/#{blob.key}?signature=test&redirect=http://evil.com",
        "https://my-bucket.s3.amazonaws.com/#{blob.key}?signature=test\"><script>alert('xss')</script>",
        "https://my-bucket.s3.amazonaws.com/#{blob.key}?signature=test%0ALocation:%20http://evil.com"
      ]

      malicious_attempts.each do |url|
        expect do
          result = Decidim::Cfj::UrlConverter.s3_url_to_global_id(url)
          # 悪意のあるパラメータが含まれていても正常に処理される
          expect(result).to eq(blob.to_global_id.to_s)
        end.not_to raise_error, "Should handle malicious URL safely: #{url}"
      end
    end
  end

  describe "Backward compatibility" do
    it "handles existing signed URLs from before the fix" do
      # 修正前のシステムで保存された可能性のあるURL
      legacy_signed_url = "https://my-bucket.s3.amazonaws.com/#{blob.key}?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIOSFODNN7EXAMPLE%2F20230101%2Fus-west-2%2Fs3%2Faws4_request&X-Amz-Date=20230101T000000Z&X-Amz-Expires=3600&X-Amz-Signature=example123&X-Amz-SignedHeaders=host"

      result = Decidim::Cfj::UrlConverter.s3_url_to_global_id(legacy_signed_url)
      expect(result).to eq(blob.to_global_id.to_s)
    end
  end

  describe "Integration with Decidim RichText" do
    it "works seamlessly with Decidim's content processing pipeline" do
      # Decidimの標準的なRichTextコンテンツ処理フローをテスト
      s3_url = "https://my-bucket.s3.amazonaws.com/#{blob.key}?signature=test"
      content = "<p>テスト画像: <img src=\"#{s3_url}\" alt=\"test\"></p>"

      # RichText属性のserialize処理を模擬
      rich_text_attribute = Decidim::Attributes::RichText.new
      serialized_content = rich_text_attribute.send(:serialize_value, content)

      # 結果の検証
      expect(serialized_content).not_to include("s3.amazonaws.com")
      expect(serialized_content).to include(blob.to_global_id.to_s)
    end
  end
end
