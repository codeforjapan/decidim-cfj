# frozen_string_literal: true

class SlackChatMessenger
  def self.notify(channel:, message:)
    unless channel && message
      Rails.logger.error "Cannot send messages to slack!"
      return
    end
    client = Slack::Web::Client.new
    client.chat_postMessage(channel:, text: message, as_user: true)
  end
end
