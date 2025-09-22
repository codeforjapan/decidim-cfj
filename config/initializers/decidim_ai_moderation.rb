Decidim::Ai::CommentModeration.configure do |config|
  config.openai_api_key = ENV["OPENAI_API_KEY"]
  config.enabled_hosts = ["localhost", "dummy.example.com"]
  config.confidence_threshold = 0.8
  config.ai_user_email = "ai-moderation@example.org"
  config.model = "gpt-4o-mini"
end
