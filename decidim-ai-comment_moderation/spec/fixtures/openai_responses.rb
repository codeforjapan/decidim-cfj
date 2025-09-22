# frozen_string_literal: true

module OpenaiResponses
  # OpenAI Chat API response format for spam content
  def spam_response
    {
      "choices" => [
        {
          "message" => {
            "role" => "assistant",
            "content" => {
              "flagged" => true,
              "categories" => {
                "spam" => true,
                "offensive" => false,
                "inappropriate" => false
              },
              "confidence" => 0.95,
              "reason" => "このコメントは広告や宣伝を含むスパムコンテンツです。"
            }.to_json
          },
          "finish_reason" => "stop",
          "index" => 0
        }
      ],
      "model" => "gpt-4o-mini",
      "usage" => {
        "prompt_tokens" => 100,
        "completion_tokens" => 50,
        "total_tokens" => 150
      }
    }
  end

  # OpenAI Chat API response format for offensive content
  def offensive_response
    {
      "choices" => [
        {
          "message" => {
            "role" => "assistant",
            "content" => {
              "flagged" => true,
              "categories" => {
                "spam" => false,
                "offensive" => true,
                "inappropriate" => false
              },
              "confidence" => 0.88,
              "reason" => "このコメントにはハラスメントや脅迫的な表現が含まれています。"
            }.to_json
          },
          "finish_reason" => "stop",
          "index" => 0
        }
      ],
      "model" => "gpt-4o-mini",
      "usage" => {
        "prompt_tokens" => 100,
        "completion_tokens" => 50,
        "total_tokens" => 150
      }
    }
  end

  # OpenAI Chat API response format for clean content
  def clean_response
    {
      "choices" => [
        {
          "message" => {
            "role" => "assistant",
            "content" => {
              "flagged" => false,
              "categories" => {
                "spam" => false,
                "offensive" => false,
                "inappropriate" => false
              },
              "confidence" => 0.01,
              "reason" => "このコメントは問題ありません。"
            }.to_json
          },
          "finish_reason" => "stop",
          "index" => 0
        }
      ],
      "model" => "gpt-4o-mini",
      "usage" => {
        "prompt_tokens" => 100,
        "completion_tokens" => 50,
        "total_tokens" => 150
      }
    }
  end

  # OpenAI Chat API response format for low confidence spam
  def low_confidence_response
    {
      "choices" => [
        {
          "message" => {
            "role" => "assistant",
            "content" => {
              "flagged" => true,
              "categories" => {
                "spam" => true,
                "offensive" => false,
                "inappropriate" => false
              },
              "confidence" => 0.45,
              "reason" => "スパムの可能性がありますが、確信度は低いです。"
            }.to_json
          },
          "finish_reason" => "stop",
          "index" => 0
        }
      ],
      "model" => "gpt-4o-mini",
      "usage" => {
        "prompt_tokens" => 100,
        "completion_tokens" => 50,
        "total_tokens" => 150
      }
    }
  end

  # OpenAI Chat API response format for inappropriate content
  def inappropriate_response
    {
      "choices" => [
        {
          "message" => {
            "role" => "assistant",
            "content" => {
              "flagged" => true,
              "categories" => {
                "spam" => false,
                "offensive" => false,
                "inappropriate" => true
              },
              "confidence" => 0.85,
              "reason" => "このコメントには不適切な内容が含まれています。"
            }.to_json
          },
          "finish_reason" => "stop",
          "index" => 0
        }
      ],
      "model" => "gpt-4o-mini",
      "usage" => {
        "prompt_tokens" => 100,
        "completion_tokens" => 50,
        "total_tokens" => 150
      }
    }
  end

  # Malformed response (missing choices)
  def malformed_response
    {
      "error" => {
        "message" => "Invalid request",
        "type" => "invalid_request_error",
        "param" => nil,
        "code" => nil
      }
    }
  end
end
