# frozen_string_literal: true

require "rails_helper"
require "decidim/blogs/test/factories"

# 本番環境での動作を模擬するテスト
# S3環境での実際の問題をテスト環境で再現し検証する
describe "Production Environment Simulation" do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization:) }
  let(:component) { create(:component, manifest_name: "blogs", organization:) }

  before do
    login_as(user, scope: :user)
  end

  describe "Signed URL expiration simulation" do
    it "simulates the original problem and verifies the fix" do
      # Step 1: 元の問題を再現 - 署名付きURLがデータベースに保存される状況
      editor_image = create(:editor_image, author: user, organization:)

      # 期限切れの署名付きURLを模擬（実際のS3環境で発生する状況）
      expired_s3_url = "https://my-bucket.s3.amazonaws.com/#{editor_image.file.blob.key}?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Expires=3600&X-Amz-Date=20230101T000000Z&X-Amz-Signature=expired_signature"

      # 古いデータを模擬（修正前のシステムで保存されたデータ）
      old_blog_post = create(:post,
                             component:,
                             body: {
                               "en" => "<p>Content with expired image: <img src=\"#{expired_s3_url}\" alt=\"old image\"> End</p>",
                               "ja" => "<p>期限切れ画像: <img src=\"#{expired_s3_url}\" alt=\"古い画像\"> 終了</p>"
                             },
                             author: user)

      # Step 2: 修正されたシステムでの編集を模擬
      # 管理者が古いコンテンツを編集する場合
      form_params = {
        title: old_blog_post.title,
        body: old_blog_post.body, # 期限切れS3 URLを含むコンテンツ
        decidim_author_id: user.id
      }

      form = Decidim::Blogs::Admin::PostForm.from_params(form_params).with_context(
        current_user: user,
        current_organization: organization,
        current_component: component
      )

      # Step 3: 更新処理（BlobParserが動作する）
      command = Decidim::Blogs::Admin::UpdatePost.new(form, old_blog_post)

      command.call do
        on(:ok) do |updated_post|
          # Step 4: 検証 - S3 URLがGlobal IDに変換されていることを確認
          expect(updated_post.body["en"]).not_to include(expired_s3_url)
          expect(updated_post.body["en"]).to include("gid://")
          expect(updated_post.body["en"]).to include(editor_image.file.blob.to_global_id.to_s)

          expect(updated_post.body["ja"]).not_to include(expired_s3_url)
          expect(updated_post.body["ja"]).to include("gid://")
        end

        on(:invalid) do |_|
          raise "Post update failed"
        end
      end
    end
  end

  describe "Mixed URL content handling" do
    it "handles content with multiple URL types from production environment" do
      editor_image1 = create(:editor_image, author: user, organization:)
      editor_image2 = create(:editor_image, author: user, organization:)

      # 本番環境で実際に発生する可能性のある複雑なコンテンツ
      mixed_content = <<~HTML
        <h2>複数の画像タイプのテスト</h2>

        <!-- 期限切れS3 URL (古いシステムからの移行データ) -->
        <p>古い画像: <img src="https://my-bucket.s3.amazonaws.com/#{editor_image1.file.blob.key}?X-Amz-Expires=3600&signature=expired" alt="old"></p>

        <!-- 現在のRails URL (エディターで追加された画像) -->
        <p>新しい画像: <img src="/rails/active_storage/blobs/redirect/#{editor_image2.file.blob.signed_id}/new-image.jpg" alt="new"></p>

        <!-- 外部URL (そのまま保持されるべき) -->
        <p>外部画像: <img src="https://example.com/external-image.jpg" alt="external"></p>

        <!-- Base64画像 (InlineImagesParserで処理される) -->
        <p>Base64画像: <img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" alt="base64"></p>

        <!-- 相対URL (変更されないべき) -->
        <p>相対画像: <img src="/assets/logo.png" alt="relative"></p>
      HTML

      # BlobParserでの処理をテスト
      parser = Decidim::ContentParsers::BlobParser.new(mixed_content, context: { user: })
      processed_content = parser.rewrite

      # S3 URLがGlobal IDに変換される
      expect(processed_content).not_to include("s3.amazonaws.com")
      expect(processed_content).to include(editor_image1.file.blob.to_global_id.to_s)

      # Rails URLがGlobal IDに変換される
      expect(processed_content).not_to include("/rails/active_storage/blobs/redirect/")
      expect(processed_content).to include(editor_image2.file.blob.to_global_id.to_s)

      # 外部URLはそのまま保持される
      expect(processed_content).to include("https://example.com/external-image.jpg")

      # 相対URLはそのまま保持される
      expect(processed_content).to include("/assets/logo.png")
    end
  end

  describe "Load testing simulation" do
    it "handles high volume of image conversions efficiently" do
      # 大量の画像を含むコンテンツ（本番環境での負荷を模擬）
      editor_images = 20.times.map { create(:editor_image, author: user, organization:) }

      # 様々なURL形式の画像を混在させた大きなコンテンツ
      large_content = editor_images.map.with_index do |img, index|
        case index % 4
        when 0
          # S3 URL
          "<img src=\"https://bucket-#{index}.s3.amazonaws.com/#{img.file.blob.key}?signature=test#{index}\" alt=\"s3-#{index}\">"
        when 1
          # Rails URL
          "<img src=\"/rails/active_storage/blobs/redirect/#{img.file.blob.signed_id}/file-#{index}.jpg\" alt=\"rails-#{index}\">"
        when 2
          # 外部URL
          "<img src=\"https://external-#{index}.com/image.jpg\" alt=\"external-#{index}\">"
        when 3
          # 相対URL
          "<img src=\"/assets/image-#{index}.png\" alt=\"relative-#{index}\">"
        end
      end.join("\n")

      # 処理時間を測定
      start_time = Time.current

      parser = Decidim::ContentParsers::BlobParser.new(large_content, context: { user: })
      processed_content = parser.rewrite

      end_time = Time.current
      processing_time = end_time - start_time

      # パフォーマンス検証
      expect(processing_time).to be < 2.0 # 2秒以内で処理完了

      # すべての内部URLが変換されていることを確認
      expect(processed_content).not_to include("s3.amazonaws.com")
      expect(processed_content).not_to include("/rails/active_storage/blobs/redirect/")

      # 外部URLと相対URLは保持されていることを確認
      expect(processed_content).to include("external-")
      expect(processed_content).to include("/assets/image-")

      # すべてのeditor_imagesのGlobal IDが含まれていることを確認
      editor_images.each_with_index do |img, index|
        next if index % 4 >= 2 # 外部URLと相対URLはスキップ

        expect(processed_content).to include(img.file.blob.to_global_id.to_s)
      end
    end
  end

  describe "Error resilience in production scenarios" do
    it "gracefully handles database connection issues" do
      editor_image = create(:editor_image, author: user, organization:)
      s3_url = "https://my-bucket.s3.amazonaws.com/#{editor_image.file.blob.key}?signature=test"

      # データベース接続エラーを模擬
      allow(ActiveStorage::Blob).to receive(:find_by).and_raise(ActiveRecord::ConnectionTimeoutError)

      content = "<img src=\"#{s3_url}\" alt=\"test\">"

      # エラーが発生してもクラッシュしない
      expect do
        parser = Decidim::ContentParsers::BlobParser.new(content, context: {})
        result = parser.rewrite

        # 変換に失敗した場合は元のURLを保持
        expect(result).to include(s3_url)
      end.not_to raise_error
    end

    it "handles memory pressure during large content processing" do
      # 非常に大きなコンテンツ（メモリ使用量をテスト）
      very_large_content = 1000.times.map do |i|
        "<p>段落 #{i}: <img src=\"https://bucket.s3.amazonaws.com/key#{i}?sig=test\" alt=\"img#{i}\"></p>"
      end.join("\n")

      # メモリ使用量を監視しながら処理
      initial_memory = `ps -o rss= -p #{Process.pid}`.to_i

      parser = Decidim::ContentParsers::BlobParser.new(very_large_content, context: {})
      result = parser.rewrite

      final_memory = `ps -o rss= -p #{Process.pid}`.to_i
      memory_increase = final_memory - initial_memory

      # メモリ使用量の増加が合理的な範囲内であることを確認（100MB以下）
      expect(memory_increase).to be < 100_000 # KB単位

      # 処理が正常に完了していることを確認
      expect(result).to be_a(String)
      expect(result.length).to be > 0
    end
  end

  describe "Cross-browser compatibility simulation" do
    it "generates URLs that work across different environments" do
      editor_image = create(:editor_image, author: user, organization:)
      global_id = editor_image.file.blob.to_global_id.to_s

      # Global IDからRails URLへの変換をテスト
      rails_url = Decidim::Cfj::UrlConverter.global_id_to_rails_url(global_id)

      expect(rails_url).to be_present
      expect(rails_url).to start_with("/rails/active_storage/blobs/")

      # URLが実際にアクセス可能であることを確認（統合テストレベル）
      # 注: 実際のHTTPリクエストは行わず、URL形式の検証のみ
      expect(rails_url).to match(%r{^/rails/active_storage/blobs/redirect/[^/]+/.+})
    end
  end
end
