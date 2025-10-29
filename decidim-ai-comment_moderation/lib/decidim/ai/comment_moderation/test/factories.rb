# frozen_string_literal: true

require "decidim/core/test/factories"

FactoryBot.define do
  factory :ai_comment_moderation, class: "Decidim::Ai::CommentModeration::CommentModeration" do
    association :commentable, factory: :comment
    analysis_result do
      {
        "flagged" => false,
        "decidim_reason" => nil,
        "confidence" => 0.8,
        "flagged_categories" => [],
        "severity" => "low",
        "categories" => {},
        "category_scores" => {}
      }
    end
    confidence_score { 0.8 }

    trait :spam do
      analysis_result do
        {
          "flagged" => true,
          "decidim_reason" => "spam",
          "confidence" => 0.9,
          "flagged_categories" => ["illicit"],
          "severity" => "high",
          "categories" => { "illicit" => true },
          "category_scores" => { "illicit" => 0.9 }
        }
      end
      confidence_score { 0.9 }
    end

    trait :offensive do
      analysis_result do
        {
          "flagged" => true,
          "decidim_reason" => "offensive",
          "confidence" => 0.85,
          "flagged_categories" => %w(harassment hate),
          "severity" => "high",
          "categories" => { "harassment" => true, "hate" => true },
          "category_scores" => { "harassment" => 0.85, "hate" => 0.7 }
        }
      end
      confidence_score { 0.85 }
    end

    trait :clean do
      analysis_result do
        {
          "flagged" => false,
          "decidim_reason" => nil,
          "confidence" => 0.05,
          "flagged_categories" => [],
          "severity" => "low",
          "categories" => {},
          "category_scores" => { "harassment" => 0.01, "hate" => 0.005 }
        }
      end
      confidence_score { 0.05 }
    end

    trait :high_severity do
      analysis_result do
        {
          "flagged" => true,
          "decidim_reason" => "offensive",
          "confidence" => 0.95,
          "flagged_categories" => ["harassment/threatening", "violence"],
          "severity" => "high",
          "categories" => { "harassment/threatening" => true, "violence" => true },
          "category_scores" => { "harassment/threatening" => 0.95, "violence" => 0.8 }
        }
      end
      confidence_score { 0.95 }
    end

    trait :inappropriate do
      analysis_result do
        {
          "flagged" => true,
          "decidim_reason" => "does_not_belong",
          "confidence" => 0.75,
          "flagged_categories" => ["sexual"],
          "severity" => "medium",
          "categories" => { "sexual" => true },
          "category_scores" => { "sexual" => 0.75 }
        }
      end
      confidence_score { 0.75 }
    end

    trait :low_confidence do
      confidence_score { 0.4 }
      analysis_result do
        {
          "flagged" => true,
          "decidim_reason" => "spam",
          "confidence" => 0.4,
          "flagged_categories" => ["illicit"],
          "severity" => "low",
          "categories" => { "illicit" => true },
          "category_scores" => { "illicit" => 0.4 }
        }
      end
    end

    trait :high_confidence do
      confidence_score { 0.95 }
      analysis_result do
        {
          "flagged" => true,
          "decidim_reason" => "offensive",
          "confidence" => 0.95,
          "flagged_categories" => ["harassment/threatening", "hate/threatening"],
          "severity" => "high",
          "categories" => { "harassment/threatening" => true, "hate/threatening" => true },
          "category_scores" => { "harassment/threatening" => 0.95, "hate/threatening" => 0.9 }
        }
      end
    end

    trait :low_severity do
      analysis_result do
        {
          "flagged" => false,
          "decidim_reason" => nil,
          "confidence" => 0.1,
          "flagged_categories" => [],
          "severity" => "low",
          "categories" => {},
          "category_scores" => {}
        }
      end
      confidence_score { 0.1 }
    end

    trait :with_reasons do
      analysis_result do
        {
          "flagged" => true,
          "decidim_reason" => "spam",
          "confidence" => 0.9,
          "flagged_categories" => %w(spam advertisement),
          "severity" => "high",
          "categories" => { "spam" => true, "advertisement" => true },
          "category_scores" => { "spam" => 0.9, "advertisement" => 0.8 },
          "reasons" => %w(spam advertisement)
        }
      end
      confidence_score { 0.9 }
    end
  end
end
