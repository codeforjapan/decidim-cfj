# frozen_string_literal: true

# Default CarrierWave setup.
#
if Rails.application.secrets.aws_access_key_id.present?
  require "carrierwave/storage/fog"

  CarrierWave::SanitizedFile.sanitize_regexp = /[^[:word:].\-+]/

  CarrierWave.configure do |config|
    config.storage = :fog
    config.fog_provider = "fog/aws"
    config.fog_public = false
    config.fog_authenticated_url_expiration = 60 * 60 * 24 * 365 * 100
    config.fog_directory = ENV.fetch("AWS_BUCKET_NAME", "cfj-decidim")
    config.asset_host = "https://s3.ap-northeast-1.amazonaws.com/cfj-decidim"
    config.fog_credentials = {
      provider: "AWS",
      aws_access_key_id: Rails.application.secrets.aws_access_key_id,
      aws_secret_access_key: Rails.application.secrets.aws_secret_access_key,
      region: "ap-northeast-1"
      # host:                  's3.ap-northeast-1.amazonaws.com',
      # endpoint:              'https://s3.example.com:8080'
    }
    # config.fog_public     = false
    config.fog_attributes = {
      "Cache-Control" => "max-age=#{365.days.to_i}",
      "X-Content-Type-Options" => "nosniff"
    }
  end
end
# Setup CarrierWave to use Amazon S3. Add `gem "fog-aws" to your Gemfile.
#
# CarrierWave.configure do |config|
#   config.storage = :fog
#   config.fog_provider = 'fog/aws'                                             # required
#   config.fog_credentials = {
#     provider:              'AWS',                                             # required
#     aws_access_key_id:     Rails.application.secrets.aws_access_key_id,     # required
#     aws_secret_access_key: Rails.application.secrets.aws_secret_access_key, # required
#     region:                'eu-west-1',                                       # optional, defaults to 'us-east-1'
#     host:                  's3.example.com',                                  # optional, defaults to nil
#     endpoint:              'https://s3.example.com:8080'                      # optional, defaults to nil
#   }
#   config.fog_directory  = 'name_of_directory'                                 # required
#   config.fog_public     = false                                               # optional, defaults to true
#   config.fog_attributes = {
#     'Cache-Control' => "max-age=#{365.day.to_i}",
#     'X-Content-Type-Options' => "nosniff"
#   }
# end
