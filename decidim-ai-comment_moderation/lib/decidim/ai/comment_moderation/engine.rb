# frozen_string_literal: true

require "rails"
require "decidim/core"

module Decidim
  module Ai
    module CommentModeration
      class Engine < ::Rails::Engine
        isolate_namespace Decidim::Ai::CommentModeration

        paths["lib/tasks"] = nil

        initializer "decidim_ai_comment_moderation.add_comment_association" do
          config.to_prepare do
            require_relative "comment_extensions"
            require_relative "system_ai_user"
            require_relative "reason_mapper"

            Decidim::Comments::Comment.include(
              Decidim::Ai::CommentModeration::CommentExtensions
            )
          end
        end

        initializer "decidim_ai_comment_moderation.events.subscribe_comments" do
          config.to_prepare do
            ActiveSupport::Notifications.subscribe("decidim.comments.comment_created") do |_event_name, data|
              Decidim::Ai::CommentModeration::AnalyzeCommentJob.perform_later(data[:comment_id])
            end
          end
        end

        initializer "decidim_ai_comment_moderation.configure_openai" do
          config.to_prepare do
            require "openai"

            OpenAI.configure do |c|
              c.access_token = Decidim::Ai::CommentModeration.config.openai_api_key
              c.request_timeout = Decidim::Ai::CommentModeration.config.openai_timeout if Decidim::Ai::CommentModeration.config.openai_timeout
            end
          end
        end

        initializer "decidim_ai_comment_moderation.log_enabled_hosts" do
          Rails.application.config.after_initialize do
            if Decidim::Ai::CommentModeration.enabled_hosts.any?
              Rails.logger.info "[AI Moderation] Enabled for organizations: #{Decidim::Ai::CommentModeration.enabled_hosts.join(", ")}"
            else
              Rails.logger.info "[AI Moderation] Not enabled for any organization"
            end
          end
        end
      end
    end
  end
end
