# frozen_string_literal: true

require "openai"

module Decidim
  module Ai
    module CommentModeration
      class OpenaiAnalyzer
        def initialize(comment)
          @comment = comment
          @client = OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY", nil))
        end

        def analyze
          return nil unless api_key_present?

          response = @client.moderations(
            parameters: {
              model: ENV.fetch("DECIDIM_AI_MODERATION_MODEL", "omni-moderation-latest"),
              input: comment_content
            }
          )

          parse_response(response)
        rescue StandardError => e
          Rails.logger.error "AI Analysis failed for comment #{@comment.id}: #{e.message}"
          nil
        end

        private

        def api_key_present?
          ENV["OPENAI_API_KEY"].present?
        end

        def comment_content
          @comment.translated_body
        end

        def parse_response(response)
          result = response.dig("results", 0)
          return nil unless result

          # Map OpenAI moderation categories to our format
          categories = result["categories"] || {}
          category_scores = result["category_scores"] || {}

          # Determine if content is spam (not directly mapped in OpenAI moderation)
          # We'll consider content spam if it's flagged but doesn't fall into harmful categories
          harmful_categories = %w[harassment harassment/threatening hate hate/threatening violence violence/graphic sexual sexual/minors self-harm self-harm/intent self-harm/instructions illicit illicit/violent]
          is_harmful = harmful_categories.any? { |cat| categories[cat] }
          is_spam = result["flagged"] && !is_harmful

          # Determine if content is offensive based on harmful categories
          is_offensive = is_harmful

          # Calculate confidence based on highest category score
          max_score = category_scores.values.max || 0.0
          confidence = [max_score, 0.9].min # Cap at 0.9 since moderation API is quite confident

          # Generate reasons based on flagged categories
          reasons = categories.select { |_, flagged| flagged }.keys

          # Determine severity based on scores
          severity = if max_score >= 0.8
                      "high"
                    elsif max_score >= 0.5
                      "medium"
                    else
                      "low"
                    end

          {
            "is_spam" => is_spam,
            "is_offensive" => is_offensive,
            "confidence" => confidence,
            "reasons" => reasons,
            "severity" => severity
          }
        rescue StandardError => e
          Rails.logger.error "Failed to parse moderation response: #{e.message}"
          nil
        end
      end
    end
  end
end
