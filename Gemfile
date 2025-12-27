# frozen_string_literal: true

source "https://rubygems.org"

ruby RUBY_VERSION

gem "decidim", "0.30.3"

gem "decidim-decidim_awesome", "0.13.1"

gem "decidim-term_customizer", git: "https://github.com/codeforjapan/decidim-module-term_customizer.git", branch: "030-ja"

gem "decidim-navigation_maps", git: "https://github.com/codeforjapan/decidim-module-navigation_maps.git", branch: "upgrade-0.30-2025-10-04"
gem "decidim-polis", git: "https://github.com/codeforjapan/decidim-polis.git", branch: "update-0-30-3"

gem "bootsnap"

gem "puma", ">= 6.3.1"
gem "puma_worker_killer"

gem "faker"

gem "wicked_pdf", "~> 2.1"

gem "deface"
gem "image_processing"
gem "newrelic_rpm"

gem "omniauth-cityos-dcp", git: "https://github.com/TheDesignium/omniauth-cityos-dcp.git", tag: "v1.4.0"
gem "omniauth-line_login", path: "omniauth-line_login"
gem "omniauth-rails_csrf_protection"

gem "decidim-broadlistening-view", git: "https://github.com/takahashim/decidim-broadlistening-view.git", branch: "030-stable"
gem "decidim-user_extension", path: "decidim-user_extension"

gem "slack-ruby-client"

group :development, :test do
  gem "byebug", "~> 11.0", platform: :mri
  gem "figaro"

  gem "decidim-dev", "0.30.3"
  gem "dotenv-rails"
  gem "factory_bot_rails"
  gem "rspec-rails"
end

group :development do
  gem "brakeman"
  gem "letter_opener_web"
  gem "listen", "~> 3.1"
  gem "rubocop-factory_bot", "~> 2.26.0", require: false
  gem "rubocop-faker"
  gem "rubocop-rspec_rails", "~> 2.30.0", require: false
  gem "web-console", "~> 4.2"
end

group :production do
  gem "aws-sdk-s3", require: false
  # gem "aws-xray-sdk", require: ["aws-xray-sdk/facets/rails/railtie"]
  gem "fog-aws"
  # gem "oj", platform: :mri
  gem "sidekiq", "6.5.12"
end

gem "rubyzip", ">= 1.0.0"
gem "zip-zip"

gem "decidim-conferences", "~> 0.30.3"
