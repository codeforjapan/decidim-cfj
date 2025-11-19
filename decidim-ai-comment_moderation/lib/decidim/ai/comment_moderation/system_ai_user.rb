# frozen_string_literal: true

module Decidim
  module Ai
    module CommentModeration
      # Class to manage AI system user for each organization
      class SystemAiUser
        AI_USER_EMAIL_PREFIX = "ai-moderation"
        AI_USER_NAME = "AI Moderator"
        AI_USER_NICKNAME_PREFIX = "ai_moderator"

        attr_reader :organization

        def initialize(organization)
          @organization = organization
        end

        # Find or create AI system user for the organization
        def find_or_create_ai_user
          user = organization.users.find_or_initialize_by(
            email: ai_user_email,
            nickname: ai_user_nickname
          )

          if user.new_record?
            setup_ai_user(user)
            user.save!
          end

          user
        end

        private

        def ai_user_email
          # Allow custom AI user email via configuration
          # If not set, default to organization-specific email
          Decidim::Ai::CommentModeration.config.ai_user_email.presence || "#{AI_USER_EMAIL_PREFIX}@#{organization.host}"
        end

        def ai_user_nickname
          "#{AI_USER_NICKNAME_PREFIX}_#{organization.id}"
        end

        def setup_ai_user(user)
          user.name = AI_USER_NAME
          user.managed = true
          user.confirmed_at = Time.current
          user.admin_terms_accepted_at = Time.current
          user.tos_agreement = true
          user.password = SecureRandom.hex(32)
          user.password_confirmation = user.password

          # Ensure the AI user doesn't receive emails
          user.email_on_moderations = false
          user.newsletter_notifications_at = nil
        end
      end
    end
  end
end
