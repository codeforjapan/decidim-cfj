# frozen_string_literal: true

Rails.application.config.to_prepare do
  Rails.application.config.session_store :cache_store if ENV["REDIS_CACHE_URL"]
end
