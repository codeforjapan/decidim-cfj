# frozen_string_literal: true

source "https://rubygems.org"

ruby RUBY_VERSION

gem "decidim", "0.25.2"

gem "decidim-comments", path: "decidim-comments"

gem "decidim-decidim_awesome", "~> 0.8.1"

gem "decidim-term_customizer", git: "https://github.com/codeforjapan/decidim-module-term_customizer.git", branch: "025-ja"

gem "bootsnap"

gem "puma", ">= 5.0.0"
gem "uglifier", "~> 4.1"

gem "faker", "~> 2.14"

gem "wicked_pdf", "~> 2.1"

gem "deface"
gem "image_processing"
gem "newrelic_rpm"

gem "omniauth-line_login", path: "omniauth-line_login"
gem "omniauth-rails_csrf_protection"

gem "decidim-user_extension", path: "decidim-user_extension"

group :development, :test do
  gem "byebug", "~> 11.0", platform: :mri
  gem "figaro"

  gem "decidim-dev", "0.25.2"
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
  gem "fog-aws"
  gem "sidekiq", "6.4.2"
end

gem "rubyzip", ">= 1.0.0"
gem "zip-zip"
