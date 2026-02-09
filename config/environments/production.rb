# frozen_string_literal: true

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Ensures that a master key has been made available in either ENV["RAILS_MASTER_KEY"]
  # or in config/master.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.action_controller.asset_host = 'http://assets.example.com'

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = 'X-Sendfile' # for Apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for NGINX

  # Store uploaded files on the local file system (see config/storage.yml for options)
  #  config.active_storage.service = :amazon

  # local storage
  config.active_storage.service = :local

  # Mount Action Cable outside main process or domain
  # config.action_cable.mount_path = nil
  # config.action_cable.url = 'wss://example.com/cable'
  # config.action_cable.allowed_request_origins = [ 'http://example.com', /http:\/\/example.*/ ]

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true
  config.force_ssl = false
  config.ssl_options = { hsts: false }

  config.action_mailer.default_url_options = { protocol: "http" }
  Rails.application.routes.default_url_options[:protocol] = "http"

  # Use the lowest log level to ensure availability of diagnostic information
  # when problems arise.
  config.log_level = :info

  # Prepend all log lines with the following tags.
  config.log_tags = [:request_id]

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store
  config.cache_store = :redis_cache_store, {
    url: ENV.fetch("REDIS_CACHE_URL", nil),
    expires_in: ENV.fetch("REDIS_CACHE_EXPIRES_IN", 60.minutes).to_i
  }
  config.session_store(:cache_store, key: "decidim_session", expire_after: Decidim.config.expire_session_after)
  config.active_storage.resolve_model_to_route = :rails_storage_proxy

  # Use a real queuing backend for Active Job (and separate queues per environment)
  # config.active_job.queue_adapter     = :resque
  # config.active_job.queue_name_prefix = "decidim-app_#{Rails.env}"

  config.action_mailer.perform_caching = false

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # --------------------
  # mail send
  # --------------------
  # mail no send
  # config.action_mailer.perform_deliveries = false

  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true

  # letter_opener_web
  # config.action_mailer.perform_deliveries = true
  # config.action_mailer.delivery_method = :letter_opener_web
  # config.action_mailer.default_url_options = { host: 'kinokawa.sekilab.global', port: 80 }

  # ses or smtp
  # config.action_mailer.perform_deliveries = true
  #config.action_mailer.delivery_method = :ses  # or :smtp
  #config.action_mailer.delivery_method = :smtp
  # config.action_mailer.smtp_settings = {
  #  address: "",
  #  port: 587,
  #  domain: "kinokawa.sekilab.global",
  #  user_name: "",
  #  password: "",
  #  authentication: :login,
  #  enable_starttls_auto: true,
  #  openssl_verify_mode: "none"
  #}
  config.action_mailer.default_options = {
    from: ENV.fetch("FROM_EMAIL", "no-reply@sekilab.global")
  }
  config.action_mailer.default_url_options = {
    host: "kinokawa.sekilab.global",
    protocol: "https"
 }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = [:ja, :en]

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = Logger::Formatter.new
  config.action_mailer.smtp_settings = {
    address: Rails.application.secrets.smtp_address,
    port: Rails.application.secrets.smtp_port,
    authentication: Rails.application.secrets.smtp_authentication,
    user_name: Rails.application.secrets.smtp_username,
    password: Rails.application.secrets.smtp_password,
    domain: Rails.application.secrets.smtp_domain,
    enable_starttls_auto: Rails.application.secrets.smtp_starttls_auto,
    openssl_verify_mode: "none"
  }

  # Use a different logger for distributed setups.
  # require 'syslog/logger'
  # config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new 'app-name')

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger = ActiveSupport::Logger.new($stdout)
    logger.formatter = config.log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false
  # Specify active_job sidekiq adapter
  config.active_job.queue_adapter = :sidekiq

  #config.hosts << "kinokawa.sekilab.global"
  #config.hosts << /.*\.sekilab\.global/
  # ヘルスチェック用
  #config.hosts << "localhost"
  #
  # IPアドレス "18.179.28.73" からのアクセスを許可する
  #config.hosts << "18.179.28.73"
  # もしポート番号込みでブロックされ続ける場合は、以下のように正規表現で許可することも可能です
  #config.hosts << /18\.179\.28\.73/

  # all host OK
  config.hosts.clear

  # HostAuthorization を無効化（切り分け用。恒久対応には非推奨）
  config.middleware.delete ActionDispatch::HostAuthorization

end
