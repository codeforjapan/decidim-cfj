# frozen_string_literal: true

require "openai"

module Decidim
  module Ai
    module CommentModeration
      class OpenaiAnalyzer
        def initialize(comment)
          @comment = comment
          @client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
        end

        def analyze
          return nil unless api_key_present?

          response = @client.chat(
            parameters: {
              model: ENV.fetch("AI_MODERATION_MODEL", "gpt-3.5-turbo"),
              messages: build_messages,
              temperature: 0.3,
              max_tokens: 500
            }
          )

          parse_response(response)
        rescue => e
          Rails.logger.error "AI Analysis failed for comment #{@comment.id}: #{e.message}"
          nil
        end

        private

        def api_key_present?
          ENV["OPENAI_API_KEY"].present?
        end

        def build_messages
          [
            {
              role: "system",
              content: moderation_prompt
            },
            {
              role: "user",
              content: comment_content
            }
          ]
        end

        def comment_content
          @comment.translated_body
        end

        def moderation_prompt
          <<~PROMPT
            You are a content moderator for a civic participation platform.
            Analyze the following comment and return a JSON response with this exact format:

            {
              "is_spam": boolean,
              "is_offensive": boolean,
              "confidence": 0.0-1.0,
              "reasons": ["reason1", "reason2"],
              "severity": "low|medium|high"
            }

            Criteria:
            - Spam: advertisements, repetitive content, unrelated content, promotional links
            - Offensive: hate speech, discrimination, personal attacks, inappropriate language
            - Confidence: how certain you are about your judgment (0.0-1.0)
            - Severity:
              - low: minor issues that might need review
              - medium: clear violations that should be reviewed
              - high: serious violations requiring immediate action

            Return ONLY the JSON object, no other text.
          PROMPT
        end

        def parse_response(response)
          content = response.dig("choices", 0, "message", "content")
          return nil unless content

          # Try to extract JSON from the response
          json_match = content.match(/\{.*\}/m)
          return nil unless json_match

          JSON.parse(json_match[0])
        rescue JSON::ParserError => e
          Rails.logger.error "Failed to parse AI response: #{e.message}"
          nil
        end
      end
    end
  end
end