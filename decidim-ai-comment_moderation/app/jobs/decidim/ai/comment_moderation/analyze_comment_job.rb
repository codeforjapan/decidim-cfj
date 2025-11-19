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

          # Store the AI analysis record
          Decidim::Ai::CommentModeration::CommentModeration.create!(
            commentable: comment,
            analysis_result: result.to_h,
            confidence_score: result.confidence
          )

          log_analysis(comment, result)

          # Auto-hide if confidence is very high
          auto_hide_comment(comment, result) if result.requires_auto_hide?

          # Create Decidim Report if needed
          if should_create_report?(result)
            create_decidim_report(comment, result)
          else
            notify_if_needed(comment, result)
          end
        rescue StandardError => e
          Rails.logger.error "Failed to analyze comment #{comment_id}: #{e.message}"
        end

        private

        def ai_moderation_enabled?(organization)
          organization.present? && Decidim::Ai::CommentModeration.enabled_for?(organization) && Decidim::Ai::CommentModeration.config.openai_api_key.present?
        end

        def already_analyzed?(comment)
          Decidim::Ai::CommentModeration::CommentModeration.exists?(
            commentable_type: "Decidim::Comments::Comment",
            commentable_id: comment.id
          )
        end

        def log_analysis(comment, result)
          Rails.logger.info(
            "[AI Moderation] Comment ##{comment.id} analyzed: " \
            "Flagged: #{result.flagged?}, " \
            "Decidim Reason: #{result.decidim_reason}, " \
            "Confidence: #{result.confidence}"
          )

          Rails.logger.info "[AI Moderation] Flagged categories: #{result.flagged_categories.join(", ")}" if result.flagged_categories.present?
        end

        def notify_if_needed(comment, result)
          # Log flagged issues that don't meet reporting threshold
          return unless result.flagged?
          return if result.requires_moderation?

          Rails.logger.info(
            "[AI Moderation] Flagged but below threshold for comment ##{comment.id}: " \
            "#{result.flagged_categories.join(", ")} (confidence: #{result.confidence})"
          )
        end

        def should_create_report?(result)
          return false unless result.flagged?
          return false if result.decidim_reason.blank?

          result.requires_moderation?
        end

        def auto_hide_comment(comment, result)
          moderation = comment.moderation || Decidim::Moderation.create!(
            reportable: comment,
            participatory_space: comment.participatory_space,
            report_count: 0
          )

          if moderation.hidden_at.nil?
            moderation.update!(hidden_at: Time.current)
            Rails.logger.info(
              "[AI Moderation] Comment ##{comment.id} auto-hidden: " \
              "confidence=#{(result.confidence * 100).round(1)}%, " \
              "reason=#{result.decidim_reason}"
            )
          end
        rescue StandardError => e
          Rails.logger.error "Failed to auto-hide comment #{comment.id}: #{e.message}"
        end

        def create_decidim_report(comment, result)
          # Use the command to create AI report
          CreateAiReport.call(comment, result.to_h) do
            on(:ok) do |_report|
              Rails.logger.info "[AI Moderation] Report created successfully for comment ##{comment.id}"
            end

            on(:invalid) do
              Rails.logger.warn "[AI Moderation] Report not created for comment ##{comment.id} (conditions not met or duplicate)"
            end
          end
        rescue StandardError => e
          Rails.logger.error "Failed to create Decidim report for comment #{comment.id}: #{e.message}"
        end
      end
    end
  end
end
