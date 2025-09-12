# frozen_string_literal: true

module Decidim
  module CloudfrontLogoHelper
    # CloudFront経由で直接S3のロゴURLを生成する
    # バリアントが未処理でも直接S3のURLを返す
    def cloudfront_logo_url(organization, logo_type = :logo)
      return unless organization.send(logo_type).attached?

      blob = organization.send(logo_type).blob
      return unless blob

      s3_key = blob.key

      "https://#{organization.host}/s3/#{s3_key}"
    end
  end
end
