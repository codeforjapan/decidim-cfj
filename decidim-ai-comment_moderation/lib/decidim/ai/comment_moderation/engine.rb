# frozen_string_literal: true

require "rails"
require "decidim/core"

module Decidim
  module Ai
    module CommentModeration
      class Engine < ::Rails::Engine
        isolate_namespace Decidim::Ai::CommentModeration

        paths["db/migrate"] = nil
        paths["lib/tasks"] = nil

        initializer "decidim_ai_comment_moderation.add_comment_hook" do
          config.to_prepare do
            require_dependency "decidim/ai/comment_moderation/comment_extensions"

            Decidim::Comments::Comment.include(
              Decidim::Ai::CommentModeration::CommentExtensions
            )
          end
        end

        initializer "decidim_ai_comment_moderation.assets" do |app|
          app.config.assets.precompile += %w(decidim_ai_comment_moderation_manifest.js)
        end
      end
    end
  end
end