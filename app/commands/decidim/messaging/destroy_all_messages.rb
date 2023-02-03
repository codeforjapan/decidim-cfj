# frozen_string_literal: true

module Decidim
  module Messaging
    # A command with all the business logic when destroys all meetings.
    class DestroyAllMessages < Rectify::Command
      # Executes the command. Broadcasts these events:
      #
      # - :ok when everything is valid and the message is deleted.
      #
      # Returns nothing.
      def call
        Decidim::Messaging::Receipt.find_each do |receipt|
          if receipt.recipient.nil?
            puts "destroy receipt id: #{receipt.id}"
            receipt.destroy!
          end
        end

        Decidim::Messaging::Message.find_each do |message|
          if message.sender.nil? && message.receipts.empty?
            puts "destroy message id: #{message.id}"
            message.destroy!
          end
        end

        Decidim::Messaging::Participation.find_each do |participation|
          if participation.participant.nil?
            puts "destroy participation id: #{participation.id}"
            participation.destroy!
          end
        end

        Decidim::Messaging::Conversation.find_each do |conversation|
          if conversation.participations.empty? && conversation.messages.empty?
            puts "destroy conversation id: #{conversation.id}"
            conversation.destroy!
          end
        end

        broadcast(:ok)
      end
    end
  end
end
