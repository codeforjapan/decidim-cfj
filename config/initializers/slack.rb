# frozen_string_literal: true

require "slack-ruby-client"

Slack.configure do |config|
  config.token = ENV["SLACK_API_TOKEN"]
  Rails.logger.error "Missing ENV[SLACK_API_TOKEN]!" unless config.token
end
