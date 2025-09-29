# frozen_string_literal: true

module Decidim
  module Ai
    module CommentModeration
      class OpenaiAnalyzer
        class Result
          attr_reader :raw_response, :categories, :category_scores, :flagged_categories

          def initialize(raw_response)
            @raw_response = raw_response
            parse_response
          end

          def flagged?
            @flagged
          end

          def high_confidence?
            confidence >= 0.8
          end

          def high_severity?
            severity == "high"
          end

          def requires_moderation?
            flagged? && high_confidence?
          end

          def requires_auto_hide?
            confidence >= 0.95 || high_risk?(level: 2)
          end

          def to_h
            {
              "flagged" => flagged?,
              "categories" => categories,
              "category_scores" => category_scores,
              "decidim_reason" => decidim_reason,
              "confidence" => confidence,
              "severity" => severity,
              "flagged_categories" => flagged_categories
            }
          end

          def to_json(*args)
            to_h.to_json(*args)
          end

          def report_details
            details = "AI-detected content issues:\n\n"
            details += "Confidence: #{(confidence * 100).round(1)}%\n"
            details += "Severity: #{severity}\n"
            details += "Flagged categories: #{flagged_categories.join(", ")}\n\n"

            top_scores = category_scores
                         .select { |_, score| score > 0.1 }
                         .sort_by { |_, score| -score }
                         .first(3)

            if top_scores.any?
              details += "Category scores:\n"
              top_scores.each do |category, score|
                details += "- #{category}: #{(score * 100).round(1)}%\n"
              end
            end

            details
          end

          private

          def parse_response
            result = raw_response.dig("results", 0)
            raise "Invalid response format" unless result

            @categories = result["categories"] || {}
            @category_scores = result["category_scores"] || {}
            @flagged = result["flagged"] || false
            @flagged_categories = @categories.select { |_, v| v }.keys
          rescue StandardError => e
            Rails.logger.error "Failed to parse OpenAI response: #{e.message}"
            set_defaults
          end

          def set_defaults
            @categories = {}
            @category_scores = {}
            @flagged = false
            @flagged_categories = []
            @confidence = 0.0
            @severity = "low"
            @decidim_reason = nil
          end

          def confidence
            @confidence ||= @category_scores.values.max || 0.0
          end

          def decidim_reason
            return nil if flagged_categories.empty?

            if offensive?
              "offensive"
            elsif inappropriate?
              "does_not_belong"
            else
              "spam"
            end
          end

          def severity
            if high_risk?
              "high"
            elsif confidence >= 0.8
              "high"
            elsif confidence >= 0.5
              "medium"
            else
              "low"
            end
          end

          def high_risk?(level: 1)
            (high_risk_categories & flagged_categories).size >= level
          end

          def high_risk_categories
            %w[
              harassment/threatening
              hate/threatening
              sexual/minors
              violence/graphic
              self-harm/intent
              illicit/violent
            ]
          end

          def offensive?
            offensive_categories =
              %w[
                harassment
                harassment/threatening
                hate
                hate/threatening
                violence
                violence/graphic
                self-harm
                self-harm/intent
                self-harm/instructions
              ]

            (offensive_categories & flagged_categories).any?
          end

          def inappropriate?
            inappropriate_categories =
              %w[
                sexual
                sexual/minors
                illicit
                illicit/violent
              ]

            (inappropriate_categories & flagged_categories).any?
          end
        end
      end
    end
  end
end
