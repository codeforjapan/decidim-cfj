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
    # Rails 8.1 のフレームワークデフォルトを使う。
    #
    # 0.30 系では decidim のジェネレータ (app_generator.rb#load_defaults_rails61) が
    # 生成直後に 7.0 -> 6.1 へ書き戻していたため 6.1 のままだった。0.31 でその処理が
    # 削除された (decidim/decidim#14735) ため 7.2 へ上げ、0.32 の Rails 8.1 化に
    # 合わせて 8.1 へ上げる (0.32 RELEASE_NOTES 2.1)。
    config.load_defaults 8.1

    # 7.2 以降の既定は SHA256 だが、切り替えると既存の暗号化 cookie がすべて無効になり、
    # ログイン中のユーザーが一斉にログアウトする。移行を別途行うまで SHA1 を維持する。
    config.active_support.key_generator_hash_digest_class = OpenSSL::Digest::SHA1

    # 8.1 の既定は「本番のみ YJIT 有効」。メモリ使用量が増えるため、本番のコンテナ
    # 割り当てを見直すまでは無効のままにする (docs/superpowers/prd-infra-issues-2026-08.md)。
    config.yjit = false

    # 0.31 までは decidim-core の active_storage_variant_processor initializer が
    # :mini_magick を強制していたが、0.32 で削除された (decidim/decidim#15670)。
    # そのまま 8.1 既定の :vips になると layout_helper.rb の
    # favicon.variant(resize: "180x180!") という ImageMagick 固有のジオメトリ指定が
    # 壊れるため、明示的に固定する。
    config.active_storage.variant_processor = :mini_magick

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
