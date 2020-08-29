# frozen_string_literal: true

source "https://rubygems.org"

ruby RUBY_VERSION

gem 'decidim',:github => 'decidim/decidim', :branch => "develop"
# gem "decidim", "0.21"
# gem "decidim-consultations", "0.23.0.dev"
# gem "decidim-initiatives", "0.23.0.dev"

gem "bootsnap", "~> 1.3"

gem "puma", ">= 4.3.5"
gem "uglifier", "~> 4.1"

gem "faker", "~> 1.9"

gem "wicked_pdf", "~> 1.4"

group :development, :test do
  gem "byebug", "~> 11.0", platform: :mri

  gem 'decidim-dev',:git => 'decidim/decidim', :branch => "develop"
end

group :development do
  gem "letter_opener_web", "~> 1.3"
  gem "listen", "~> 3.1"
  gem "spring", "~> 2.0"
  gem "spring-watcher-listen", "~> 2.0"
  gem "web-console", "~> 3.5"
end
