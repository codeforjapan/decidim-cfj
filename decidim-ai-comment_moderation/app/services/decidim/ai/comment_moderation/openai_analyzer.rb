# frozen_string_literal: true

require "openai"
require "json"

module Decidim
  module Ai
    module CommentModeration
      class OpenaiAnalyzer
        attr_reader :comment

        SYSTEM_PROMPT = <<~PROMPT
          あなたはコメントのモデレーションを行うAIアシスタントです。
          与えられたコメントを分析し、以下のカテゴリに該当するかどうかを判定してください：

          1. spam（スパム）: 広告、宣伝、無関係なリンク、繰り返し投稿など
          2. offensive（攻撃的）: ハラスメント、脅迫、ヘイトスピーチ、暴力的な表現など
          3. inappropriate（不適切）: 性的なコンテンツ、違法な内容、その他不適切な表現など

          必ずJSON形式で以下のような応答を返してください：
          {
            "flagged": true/false,
            "categories": {
              "spam": true/false,
              "offensive": true/false,
              "inappropriate": true/false
            },
            "confidence": 0.0-1.0,
            "reason": "判定理由の説明"
          }
        PROMPT

        def initialize(comment)
          @comment = comment
          api_key = Decidim::Ai::CommentModeration.config.openai_api_key
          @client = OpenAI::Client.new(access_token: api_key) if api_key.present?
        end

        def analyze
          return nil if Decidim::Ai::CommentModeration.config.openai_api_key.blank?
          return nil unless @client

          response = @client.chat(
            parameters: {
              model: model_name,
              messages: [
                { role: "system", content: SYSTEM_PROMPT },
                { role: "user", content: @comment.translated_body }
              ],
              temperature: 0.3,
              response_format: { type: "json_object" }
            }
          )

          Result.new(response, @comment.translated_body)
        rescue StandardError => e
          Rails.logger.error "AI Analysis failed for comment #{@comment.id}: #{e.message}"
          Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
          nil
        end

        private

        def model_name
          Decidim::Ai::CommentModeration.config.model
        end
      end
    end
  end
end
