# frozen_string_literal: true

module Decidim
  module Ai
    module CommentModeration
      class AnalyzeCommentJob < ApplicationJob
        queue_as :events

        def perform(comment_id)
          comment = Decidim::Comments::Comment.find_by(id: comment_id)
          return unless comment

          organization = comment.organization
          return unless ai_moderation_enabled?(organization)

          # Skip if already analyzed
          return if already_analyzed?(comment)

          analyzer = OpenaiAnalyzer.new(comment)
          result = analyzer.analyze

          return unless result

          moderation = Decidim::Ai::CommentModeration.create!(
            commentable: comment,
            analysis_result: result,
            confidence_score: result["confidence"]
          )

          log_analysis(comment, result)
          notify_if_needed(comment, moderation)
        rescue StandardError => e
          Rails.logger.error "Failed to analyze comment #{comment_id}: #{e.message}"
        end

        private

        def ai_moderation_enabled?(organization)
          organization.present? && Decidim::Ai::CommentModeration::Config.enabled_for?(organization) && ENV["OPENAI_API_KEY"].present?
        end

        def already_analyzed?(comment)
          Decidim::Ai::CommentModeration.exists?(
            commentable_type: "Decidim::Comments::Comment",
            commentable_id: comment.id
          )
        end

        def log_analysis(comment, result)
          Rails.logger.info(
            "[AI Moderation] Comment ##{comment.id} analyzed: " \
            "Spam: #{result["is_spam"]}, " \
            "Offensive: #{result["is_offensive"]}, " \
            "Confidence: #{result["confidence"]}, " \
            "Severity: #{result["severity"]}"
          )

          Rails.logger.info "[AI Moderation] Reasons: #{result["reasons"].join(", ")}" if result["reasons"].present?
        end

        def notify_if_needed(comment, moderation)
          return unless moderation.requires_moderation?

          # Log high-severity issues for now
          Rails.logger.warn(
            "[AI Moderation] High-confidence issue detected for comment ##{comment.id}: " \
            "#{moderation.reasons.join(", ")}"
          )

          # TODO: In the future, we can add:
          # - Email notification to moderators
          # - Auto-hide functionality
          # - Create a Decidim::Report record
        end
      end
    end
  end
end
