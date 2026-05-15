# frozen_string_literal: true

# Disable the Decidim direct messaging (conversations) feature.
# - Makes every user reject incoming conversations so that "Send private message"
#   buttons in decidim-core views (profile sidebar, author cells, etc.) are hidden.
# - Suppresses all ConversationMailer deliveries as a defense in depth in case a
#   conversation record is somehow created (e.g. via background jobs).
# Routes are also redirected at config/routes.rb.

Rails.application.config.to_prepare do
  Decidim::User.class_eval do
    def accepts_conversation?(_user)
      false
    end
  end

  module DisableConversationMailerDelivery
    def process(*)
      super
      message.perform_deliveries = false
    end
  end
  Decidim::Messaging::ConversationMailer.prepend(DisableConversationMailerDelivery)
end
