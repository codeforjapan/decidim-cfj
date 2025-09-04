# frozen_string_literal: true

module Decidim
  module CloudfrontLogoHelper
    # CloudFront経由で直接S3のロゴURLを生成する
    # バリアントが未処理でも直接S3のURLを返す
    def cloudfront_logo_url(organization, logo_type = :logo, variant = :medium)
      return unless organization.send(logo_type).attached?

      pp 'logo_typelogo_typelogo_typelogo_typelogo_typelogo_type'
      pp logo_type

      blob = organization.send(logo_type).blob
      return unless blob

      # CloudFrontのホスト設定を取得
      cdn_host = Rails.application.secrets.dig(:storage, :cdn_host)

      # バリアントが未処理の場合、オリジナルのS3キーを使用
      s3_key = blob.key
      filename = blob.filename.to_s

      # CloudFront + S3の直接URLを構築
      "https://#{cdn_host}/#{s3_key}"
    end

    # デスクトップロゴ用のヘルパー
    def cloudfront_desktop_logo_url(organization)
      cloudfront_logo_url(organization, :logo, :medium)
    end

    # モバイルロゴ用のヘルパー
    def cloudfront_mobile_logo_url(organization)
      if organization.mobile_logo.attached?
        cloudfront_logo_url(organization, :mobile_logo, :medium)
      elsif organization.favicon.attached?
        cloudfront_logo_url(organization, :favicon, :medium)
      end
    end
  end
end