# frozen_string_literal: true

source "https://rubygems.org"

ruby RUBY_VERSION

gem "decidim", "0.23.5"

# gem "decidim", "0.23.5"
# gem "decidim-consultations", "0.23.5"
# gem "decidim-initiatives", "0.23.5"

gem "decidim-comments", path: "decidim-comments"

gem "decidim-decidim_awesome", "~> 0.7.0"

gem "bootsnap", "~> 1.3"

gem "puma", ">= 4.3.5"
gem "uglifier", "~> 4.1"

gem "faker", "~> 1.9"

gem "wicked_pdf", "~> 1.4"

gem "deface"
gem "newrelic_rpm"

gem "decidim-user_extension", path: "decidim-user_extension"

# When rails >= 5.2.5 or 6.0.3.6, you can remove this gem.
gem "mimemagic", "~> 0.3.10"

group :development, :test do
  gem "byebug", "~> 11.0", platform: :mri
  gem "figaro"

  gem "decidim-dev", "0.23.5"
  gem "dotenv-rails"
  gem "factory_bot_rails"
  gem "rspec-rails"
end

group :development do
  gem "letter_opener_web", "~> 1.3"
  gem "listen", "~> 3.1"
  gem "spring", "~> 2.0"
  gem "spring-watcher-listen", "~> 2.0"
  gem "web-console", "~> 3.5"
end

group :production do
  gem "fog-aws"
  gem "sidekiq", "5.2.7"
end

gem "rubyzip", ">= 1.0.0"
gem "zip-zip"
