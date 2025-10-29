# frozen_string_literal: true

module Decidim
  module Ai
    module CommentModeration
      class OpenaiAnalyzer
        class Result
          attr_reader :raw_response, :comment_text

          def initialize(response, comment_text)
            @raw_response = response
            @comment_text = comment_text
            validate_response!
            parse_ai_response!
          end

          def flagged?
            @ai_result["flagged"] == true
          end

          def confidence
            @ai_result["confidence"].to_f
          end

          def decidim_reason
            return nil unless flagged?

            categories = @ai_result["categories"] || {}

            if categories["offensive"]
              "offensive"
            elsif categories["spam"]
              "spam"
            else
              "does_not_belong"
            end
          end

          def flagged_categories
            categories = @ai_result["categories"] || {}
            categories.select { |_cat, flagged| flagged }.keys
          end

          def severity
            if confidence >= 0.8
              "high"
            elsif confidence >= 0.5
              "medium"
            else
              "low"
            end
          end

          def categories
            @ai_result["categories"] || {}
          end

          def ai_reason
            @ai_result["reason"]
          end

          def to_h
            {
              flagged: flagged?,
              decidim_reason:,
              confidence:,
              severity:,
              flagged_categories:,
              categories:,
              reason: ai_reason
            }
          end

          def requires_moderation?
            return false unless flagged?

            confidence >= threshold
          end

          private

          def validate_response!
            raise StandardError, "Failed to parse chat API response: invalid format" unless @raw_response.is_a?(Hash) && @raw_response.dig("choices", 0, "message", "content")
          rescue StandardError => e
            Rails.logger.error e.message
            raise
          end

          def parse_ai_response!
            content = @raw_response.dig("choices", 0, "message", "content")
            @ai_result = JSON.parse(content)

            # Ensure required fields exist with defaults
            @ai_result["flagged"] ||= false
            @ai_result["categories"] ||= { "spam" => false, "offensive" => false, "inappropriate" => false }
            @ai_result["confidence"] ||= 0.0
            @ai_result["reason"] ||= ""
          rescue JSON::ParserError => e
            Rails.logger.error "Failed to parse AI response JSON: #{e.message}"
            Rails.logger.error "Response content: #{content}"

            # Fallback to safe defaults
            @ai_result = {
              "flagged" => false,
              "categories" => { "spam" => false, "offensive" => false, "inappropriate" => false },
              "confidence" => 0.0,
              "reason" => "Failed to parse AI response"
            }
          end

          def threshold
            Decidim::Ai::CommentModeration.confidence_threshold
          end
        end
      end
    end
  end
end
