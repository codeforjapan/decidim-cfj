# frozen_string_literal: true

require "rails_helper"
require_relative "../../../../lib/decidim/cfj/url_converter"

# エッジケースと堅牢性のテスト
describe "UrlConverter Edge Cases and Robustness" do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization:) }
  let(:editor_image) { create(:editor_image, author: user, organization:) }
  let(:blob) { editor_image.file.blob }

  describe "URL format variations" do
    it "handles different S3 URL formats correctly" do
      # 実際のS3で生成される可能性のある様々なURL形式
      s3_url_variations = [
        # 標準形式
        "https://my-bucket.s3.amazonaws.com/#{blob.key}?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=credential&X-Amz-Date=date&X-Amz-Expires=3600&X-Amz-Signature=signature&X-Amz-SignedHeaders=headers",

        # 短い形式
        "https://my-bucket.s3.amazonaws.com/#{blob.key}?signature=abc123",

        # リージョン指定あり
        "https://my-bucket.s3.us-west-2.amazonaws.com/#{blob.key}?X-Amz-Expires=3600",

        # 複数のクエリパラメータ
        "https://my-bucket.s3.amazonaws.com/#{blob.key}?response-content-disposition=attachment&X-Amz-Expires=3600&other=value",

        # エンコードされたキー
        "https://my-bucket.s3.amazonaws.com/#{CGI.escape(blob.key)}?signature=test"

        # 注意: 以下のパターンは現在のS3_URL_REGEXではサポートされていません:
        # China region: "https://my-bucket.s3.cn-north-1.amazonaws.com.cn/#{blob.key}?signature=test"
        # GovCloud: "https://my-bucket.s3.us-gov-west-1.amazonaws.com/#{blob.key}?signature=test"
      ]

      s3_url_variations.each do |url|
        result = Decidim::Cfj::UrlConverter.s3_url_to_global_id(url)
        expect(result).to eq(blob.to_global_id.to_s), "Failed to convert: #{url}"
      end
    end

    it "handles edge cases in key extraction" do
      # 特殊文字を含むキーのテスト
      special_keys = [
        "path/with/slashes/file.jpg",
        "file with spaces.jpg",
        "file-with-dashes_and_underscores.jpg",
        "ファイル名.jpg", # 日本語
        "file.with.multiple.dots.jpg",
        "UPPERCASE_FILE.JPG",
        "123-numeric-start.jpg"
      ]

      special_keys.each do |key|
        # エンコードされたキーとオリジナルキーの両方でモックを設定
        encoded_key = CGI.escape(key)
        mock_blob = double("blob", key:, to_global_id: double("gid", to_s: "gid://test/Blob/#{key.hash}"))

        # URLConverterがエンコードされたキーで検索する場合に対応
        allow(ActiveStorage::Blob).to receive(:find_by).with(key: encoded_key).and_return(mock_blob)
        allow(ActiveStorage::Blob).to receive(:find_by).with(key:).and_return(mock_blob)

        url = "https://my-bucket.s3.amazonaws.com/#{encoded_key}?signature=test"
        result = Decidim::Cfj::UrlConverter.s3_url_to_global_id(url)

        expect(result).to eq(mock_blob.to_global_id.to_s), "Failed for key: #{key}"
      end
    end
  end

  describe "Malformed input handling" do
    it "gracefully handles malformed URLs" do
      malformed_urls = [
        nil,
        "",
        "not-a-url",
        "https://",
        "https://example.com",
        "https://s3.amazonaws.com", # S3ドメインだがパスなし
        "https://my-bucket.s3.amazonaws.com/", # キーなし
        "https://my-bucket.s3.amazonaws.com/?", # 空のクエリ
        "ftp://my-bucket.s3.amazonaws.com/key", # 間違ったプロトコル
        "https://my-bucket.s2.amazonaws.com/key", # 間違ったサービス名
        "javascript:alert('xss')", # XSS試行
        "<script>alert('xss')</script>" # HTMLタグ
      ]

      malformed_urls.each do |url|
        expect do
          result = Decidim::Cfj::UrlConverter.s3_url_to_global_id(url)
          expect(result).to be_nil, "Should return nil for malformed URL: #{url.inspect}"
        end.not_to raise_error, "Should not raise error for: #{url.inspect}"
      end
    end

    it "handles very long URLs" do
      # 非常に長いURLの処理
      very_long_key = "a" * 1000
      long_url = "https://my-bucket.s3.amazonaws.com/#{very_long_key}?signature=#{"b" * 1000}"

      expect do
        result = Decidim::Cfj::UrlConverter.s3_url_to_global_id(long_url)
        expect(result).to be_nil # 存在しないキーなのでnil
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
          # 存在しないファイルなのでnilが返る
          expect(result).to be_nil
        end.not_to raise_error, "Should handle unicode URL: #{url}"
      end
    end
  end

  describe "Security considerations" do
    it "prevents URL injection attacks" do
      # URL injectionの試行
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
        "gid://app/Model/abc", # 非数値ID
        "javascript:alert('xss')",
        "<script>alert('xss')</script>",
        "gid://evil-app/EvilModel/123" # 異なるアプリのGID
      ]

      invalid_global_ids.each do |gid|
        expect do
          result = Decidim::Cfj::UrlConverter.global_id_to_rails_url(gid)
          expect(result).to be_nil, "Should return nil for invalid GID: #{gid.inspect}"
        end.not_to raise_error, "Should handle invalid GID safely: #{gid.inspect}"
      end
    end
  end

  describe "Performance under stress" do
    it "handles concurrent access efficiently" do
      # 並行処理のテスト
      threads = []
      results = []
      mutex = Mutex.new

      # 複数スレッドで同時にURL変換を実行
      10.times do
        threads << Thread.new do
          s3_url = "https://my-bucket.s3.amazonaws.com/#{blob.key}?signature=#{Thread.current.object_id}"
          result = Decidim::Cfj::UrlConverter.s3_url_to_global_id(s3_url)

          mutex.synchronize do
            results << result
          end
        end
      end

      threads.each(&:join)

      # すべてのスレッドが同じ結果を返すことを確認
      expect(results.all? { |r| r == blob.to_global_id.to_s }).to be true
      expect(results.length).to eq(10)
    end

    it "maintains performance with cache pressure" do
      # キャッシュプレッシャー下でのパフォーマンステスト
      # 大量の異なるURLで変換を試行

      start_time = Time.current

      1000.times do |i|
        # 存在しないキーでの変換（キャッシュミスを意図的に発生）
        fake_url = "https://bucket-#{i}.s3.amazonaws.com/fake-key-#{i}?signature=test"
        Decidim::Cfj::UrlConverter.s3_url_to_global_id(fake_url)
      end

      end_time = Time.current
      total_time = end_time - start_time

      # 1000回の変換が2秒以内で完了することを確認
      expect(total_time).to be < 2.0
    end
  end

  describe "Error boundary testing" do
    it "handles ActiveRecord errors gracefully" do
      s3_url = "https://my-bucket.s3.amazonaws.com/#{blob.key}?signature=test"

      # 様々なActiveRecordエラーを模擬
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

    it "handles encoding issues" do
      # 文字エンコーディングの問題をテスト
      encoding_test_urls = [
        "https://my-bucket.s3.amazonaws.com/#{blob.key}?signature=test".force_encoding("ASCII-8BIT"),
        "https://my-bucket.s3.amazonaws.com/#{blob.key}?signature=test".encode("ISO-8859-1")
      ]

      encoding_test_urls.each do |url|
        expect do
          result = Decidim::Cfj::UrlConverter.s3_url_to_global_id(url)
          expect(result).to eq(blob.to_global_id.to_s)
        end.not_to raise_error, "Should handle encoding: #{url.encoding}"
      end
    end
  end

  describe "Memory management" do
    it "does not leak memory during repeated conversions" do
      # メモリリークの検出
      initial_objects = ObjectSpace.count_objects

      # 大量の変換を実行
      1000.times do |i|
        s3_url = "https://bucket-#{i}.s3.amazonaws.com/#{blob.key}?signature=test#{i}"
        Decidim::Cfj::UrlConverter.s3_url_to_global_id(s3_url)
      end

      # ガベージコレクションを強制実行
      GC.start

      final_objects = ObjectSpace.count_objects

      # オブジェクト数の増加が合理的な範囲内であることを確認
      object_increase = final_objects[:TOTAL] - initial_objects[:TOTAL]
      expect(object_increase).to be < 10_000, "Potential memory leak detected"
    end
  end
end
