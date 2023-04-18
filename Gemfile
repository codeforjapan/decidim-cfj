# frozen_string_literal: true

source "https://rubygems.org"

ruby RUBY_VERSION

gem "decidim", "0.26.5"

gem "decidim-comments", path: "decidim-comments"

gem "decidim-decidim_awesome", git: "https://github.com/codeforjapan/decidim-module-decidim_awesome.git", branch: "v0.9.0-2023-03-30"

gem "decidim-term_customizer", git: "https://github.com/codeforjapan/decidim-module-term_customizer.git", branch: "026-ja"

gem "bootsnap"

gem "puma", ">= 5.0.0"
gem "puma_worker_killer"

gem "uglifier", "~> 4.1"

gem "faker", "~> 2.14"

gem "wicked_pdf", "~> 2.1"

gem "deface"
gem "image_processing"
gem "newrelic_rpm"

gem "omniauth-line_login", path: "omniauth-line_login"
gem "omniauth-rails_csrf_protection"

gem "decidim-user_extension", path: "decidim-user_extension"

gem "slack-ruby-client"

group :development, :test do
  gem "byebug", "~> 11.0", platform: :mri
  gem "figaro"

  gem "decidim-dev", "0.26.5"
  gem "dotenv-rails"
  gem "factory_bot_rails"
  gem "rspec-rails"
end

group :development do
  gem "letter_opener_web", "~> 1.3"
  gem "listen", "~> 3.1"
  gem "rubocop-faker"
  gem "spring", "~> 2.0"
  gem "spring-watcher-listen", "~> 2.0"
  gem "web-console", "~> 3.5"
end

group :production do
  gem "aws-sdk-s3", require: false
  gem "aws-xray-sdk", require: ["aws-xray-sdk/facets/rails/railtie"]
  gem "fog-aws"
  gem "oj", platform: :mri
  gem "sidekiq", "6.4.2"
end

gem "rubyzip", ">= 1.0.0"
gem "zip-zip"
