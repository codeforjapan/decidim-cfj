# frozen_string_literal: true

require "active_support/configurable"
require "decidim/ai/comment_moderation/version"
require "decidim/ai/comment_moderation/engine"

module Decidim
  module Ai
    module CommentModeration
      include ActiveSupport::Configurable

      # Configuration example (config/initializers/decidim_ai_comment_moderation.rb):
      #
      #   Decidim::Ai::CommentModeration.configure do |config|
      #     config.openai_api_key = ENV["OPENAI_API_KEY"]
      #     config.enabled_hosts = ["example.org", "demo.example.org"]
      #     config.confidence_threshold = 0.8
      #     config.ai_user_email = "ai-moderation@example.org"
      #     config.model = "gpt-4o-mini"
      #   end

      # OpenAI API key (required)
      config_accessor :openai_api_key, instance_writer: false

      # List of organization hosts where AI moderation is enabled
      config_accessor :enabled_hosts do
        []
      end

      # Confidence threshold for creating reports (0.0 to 1.0)
      config_accessor :confidence_threshold do
        0.8
      end

      # AI user email address (optional)
      # If not set, defaults to organization-specific email: ai-moderation@{organization.host}
      config_accessor :ai_user_email, instance_writer: false

      # OpenAI model to use
      config_accessor :model do
        "gpt-4o-mini"
      end

      # Check if AI moderation is enabled for an organization
      def self.enabled_for?(organization)
        return false unless organization
        return false if config.enabled_hosts.empty?

        config.enabled_hosts.include?(organization.host)
      end
    end
  end
end
