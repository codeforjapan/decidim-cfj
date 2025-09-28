# frozen_string_literal: true

module Decidim
  module Ai
    class CommentModeration < ApplicationRecord
      self.table_name = "decidim_ai_comment_moderations"

      belongs_to :commentable, polymorphic: true

      validates :confidence_score,
                numericality: { greater_than_or_equal_to: 0,
                                less_than_or_equal_to: 1 },
                allow_nil: true

      scope :high_confidence, -> { where("confidence_score > ?", 0.8) }
      scope :spam_detected, -> { where("analysis_result->>'is_spam' = ?", "true") }
      scope :offensive_detected, -> { where("analysis_result->>'is_offensive' = ?", "true") }
      scope :recent, -> { order(created_at: :desc) }

      def spam?
        analysis_result["is_spam"] == true
      end

      def offensive?
        analysis_result["is_offensive"] == true
      end

      def high_severity?
        analysis_result["severity"] == "high"
      end

      def reasons
        analysis_result["reasons"] || []
      end

      def requires_moderation?
        (spam? || offensive?) && high_confidence?
      end

      def high_confidence?
        confidence_score && confidence_score > 0.8
      end
    end
  end
end
