# frozen_string_literal: true

module Decidim
  module Ai
    module CommentModeration
      module CommentExtensions
        extend ActiveSupport::Concern

        included do
          has_one :ai_moderation,
                  class_name: "Decidim::Ai::CommentModeration::CommentModeration",
                  as: :commentable,
                  dependent: :destroy
        end
      end
    end
  end
end
