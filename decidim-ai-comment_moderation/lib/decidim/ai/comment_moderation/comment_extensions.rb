# frozen_string_literal: true

module Decidim
  module Ai
    module CommentModeration
      module CommentExtensions
        extend ActiveSupport::Concern

        included do
          has_one :ai_moderation,
                  class_name: "Decidim::Ai::CommentModeration",
                  as: :commentable,
                  dependent: :destroy

          after_create :schedule_ai_analysis
        end

        private

        def schedule_ai_analysis
          return unless ai_moderation_enabled?

          Decidim::Ai::CommentModeration::AnalyzeCommentJob.perform_later(id)
        rescue => e
          Rails.logger.error "Failed to schedule AI analysis for comment #{id}: #{e.message}"
        end

        def ai_moderation_enabled?
          # Check if AI moderation is enabled via environment variable
          ENV["AI_MODERATION_ENABLED"] == "true" && ENV["OPENAI_API_KEY"].present?
        end
      end
    end
  end
end