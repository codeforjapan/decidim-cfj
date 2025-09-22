# Decidim::Ai::CommentModeration

AI-powered comment moderation module for Decidim v0.29.2 using OpenAI.

## Features

- Automatic spam and offensive content detection
- Confidence-based moderation decisions
- Detailed logging of AI analysis results
- Support for Japanese and English

## Installation

Add this line to your application's Gemfile:

```ruby
gem "decidim-ai-comment_moderation", path: "decidim-ai-comment_moderation"
```

And then execute:

```bash
$ bundle install
```

Run the migrations:

```bash
$ rails decidim_ai_comment_moderation:install:migrations
$ rails db:migrate
```

## Configuration

Set the following environment variables in your `.env` file:

```bash
# Required
OPENAI_API_KEY=sk-...

# Optional (with defaults)
AI_MODERATION_ENABLED=true
AI_MODERATION_MODEL=gpt-3.5-turbo
```

## Usage

Once installed and configured, the module will automatically:

1. Monitor new comments as they are created
2. Send them to OpenAI for analysis
3. Store the analysis results in the database
4. Log potential issues for moderator review

### Checking Analysis Results

```ruby
# In Rails console
comment = Decidim::Comments::Comment.last
moderation = comment.ai_moderation

# Check if spam or offensive
moderation.spam?
moderation.offensive?

# Get confidence score
moderation.confidence_score

# Get reasons
moderation.reasons
```

### Monitoring Logs

The module logs all analysis results. Look for `[AI Moderation]` in your Rails logs:

```
[AI Moderation] Comment #123 analyzed: Spam: true, Offensive: false, Confidence: 0.92, Severity: high
[AI Moderation] Reasons: advertisement, promotional links
```

## Database Schema

The module creates a `decidim_ai_comment_moderations` table with:

- `commentable_type` and `commentable_id`: Polymorphic association to comments
- `analysis_result`: JSONB field containing the full AI analysis
- `confidence_score`: Float value (0.0-1.0) indicating AI confidence
- `created_at` and `updated_at`: Timestamps

## AI Analysis Response Format

The AI returns analysis in the following format:

```json
{
  "is_spam": boolean,
  "is_offensive": boolean,
  "confidence": 0.0-1.0,
  "reasons": ["reason1", "reason2"],
  "severity": "low|medium|high"
}
```

## Future Enhancements

- Admin dashboard for reviewing AI moderations
- Auto-hide functionality for high-confidence violations
- Support for other AI providers (Anthropic, etc.)
- Feedback mechanism for improving AI accuracy
- Integration with Decidim's existing moderation system

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/codeforjapan/decidim-cfj.

## License

This module is available as open source under the terms of the [AGPL-3.0 License](https://opensource.org/licenses/AGPL-3.0).