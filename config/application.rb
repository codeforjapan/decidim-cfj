# frozen_string_literal: true

require_relative "boot"

require "decidim/rails"
# Add the frameworks used by your app that are not loaded by Decidim.
# require "action_cable/engine"
# require "action_mailbox/engine"
# require "action_text/engine"
require "zip"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module DecidimApp
  class Application < Rails::Application
    # Rails 7.2 のフレームワークデフォルトを使う。
    #
    # 0.30 系では decidim のジェネレータ (app_generator.rb#load_defaults_rails61) が
    # 生成直後に 7.0 -> 6.1 へ書き戻していたため 6.1 のままだった。0.31 でその処理が
    # 削除された (decidim/decidim#14735) ので、本体の Rails 7.2 に合わせて上げる。
    config.load_defaults 7.2

    # 7.2 の既定は SHA256 だが、切り替えると既存の暗号化 cookie がすべて無効になり、
    # ログイン中のユーザーが一斉にログアウトする。移行を別途行うまで SHA1 を維持する。
    config.active_support.key_generator_hash_digest_class = OpenSSL::Digest::SHA1

    # 7.2 の既定は YJIT 有効。メモリ使用量が増えるため、本番のコンテナ割り当てを
    # 見直すまでは無効のままにする (docs/superpowers/prd-infra-issues-2026-08.md)。
    config.yjit = false

    config.generators do |g|
      # remove some specs
      g.test_framework :rspec,
                       fixtures: true,
                       view_specs: false,
                       helper_specs: false,
                       routing_specs: false

      g.fixture_replacement :factory_bot, dir: "spec/factories"
    end

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
  end
end
