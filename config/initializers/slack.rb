# frozen_string_literal: true

require "slack-ruby-client"
require_relative "../../lib/slack_chat_messenger"

Slack.configure do |config|
  config.token = ENV.fetch("SLACK_API_TOKEN", nil)
  Rails.logger.error "Missing ENV[SLACK_API_TOKEN]!" unless config.token
end
