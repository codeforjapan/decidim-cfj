# frozen_string_literal: true

module Decidim
  module Ai
    module CommentModeration
      # Maps AI analysis results to Decidim report reasons
      class ReasonMapper
        # Decidim report reasons from Decidim::Report::REASONS
        DECIDIM_REASONS = %w(spam offensive does_not_belong hidden_during_block).freeze

        attr_reader :ai_analysis_result

        def initialize(ai_analysis_result)
          @ai_analysis_result = ai_analysis_result
        end

        # Determine if the AI analysis warrants creating a report
        # Simplified: only check if flagged and meets confidence threshold
        def should_report?
          return false unless ai_analysis_result.is_a?(Hash)
          return false unless ai_analysis_result[:flagged] == true

          meets_confidence_threshold?
        end

        # Map AI analysis to appropriate Decidim report reason
        # Uses the decidim_reason from the AI analysis result
        def decidim_reason
          return nil unless should_report?

          ai_analysis_result[:decidim_reason] || "does_not_belong"
        end

        # Generate detailed report description based on AI analysis
        def report_details
          return "" unless should_report?

          details = []
          details << "AI自動検出による通報"
          details << "信頼度: #{confidence_percentage}"

          details << "検出カテゴリ: #{flagged_categories.join(", ")}" if flagged_categories.any?

          details.join("\n")
        end

        # Get confidence score as percentage
        def confidence_percentage
          return "不明" unless ai_analysis_result[:confidence].is_a?(Numeric)

          "#{(ai_analysis_result[:confidence] * 100).round(1)}%"
        end

        # Get flagged categories from AI analysis
        def flagged_categories
          ai_analysis_result[:flagged_categories] || []
        end

        # Check if confidence meets minimum threshold
        # Uses the simplified configuration threshold
        def meets_confidence_threshold?
          return false unless ai_analysis_result[:confidence].is_a?(Numeric)

          ai_analysis_result[:confidence] >= Decidim::Ai::CommentModeration.confidence_threshold
        end
      end
    end
  end
end
