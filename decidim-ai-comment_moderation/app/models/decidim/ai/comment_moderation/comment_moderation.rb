# frozen_string_literal: true

module Decidim
  module Ai
    module CommentModeration
      class CommentModeration < ApplicationRecord
        belongs_to :commentable, polymorphic: true, optional: false

        # Store accessor for analysis_result JSONB field
        store_accessor :analysis_result, :flagged, :decidim_reason, :severity, :confidence,
                       :flagged_categories, :categories

        validates :confidence_score,
                  numericality: { greater_than_or_equal_to: 0,
                                  less_than_or_equal_to: 1 },
                  allow_nil: true

        scope :high_confidence, -> { where("confidence_score > ?", 0.8) }
        scope :flagged_content, -> { where("analysis_result ->> 'flagged' IN ('true', 't', '1')") }
        scope :spam_detected, -> { where("analysis_result ->> 'decidim_reason' = ?", "spam") }
        scope :offensive_detected, -> { where("analysis_result ->> 'decidim_reason' = ?", "offensive") }
        scope :recent, -> { order(created_at: :desc) }

        # Type casting for store_accessor fields
        def flagged
          super.in?([true, "true", 1, "1"])
        end
        alias flagged? flagged

        def flagged_categories
          super || []
        end

        def categories
          super || {}
        end

        # Convenience methods
        def spam?
          decidim_reason == "spam"
        end

        def offensive?
          decidim_reason == "offensive"
        end

        def inappropriate?
          decidim_reason == "does_not_belong"
        end

        def requires_moderation?
          flagged? && high_confidence?
        end

        def high_confidence?
          return false if confidence_score.nil?

          confidence_score > 0.8
        end
      end
    end
  end
end
