# frozen_string_literal: true

module Decidim
  module ContentBlocks
    # A cell to be rendered as a content block with the latest comments performed
    # in a Decidim Organization.
    class LastCommentCell < Decidim::ViewModel
      include Decidim::Core::Engine.routes.url_helpers

      def show
        return if valid_comments.empty?

        render
      end

      # The comments to be displayed at the content block.
      #
      # We need to build the collection this way because an ActionLog has
      # polymorphic relations to different kind of models, and these models
      # might not be available (a proposal might have been hidden or withdrawn).
      #
      # Since these conditions can't always be filtered with a database search
      # we ask for more comments than we actually need and then loop until there
      # are enough of them.
      #
      # Returns an Array of ActionLogs.
      def valid_comments
        return @valid_comments if defined?(@valid_comments)

        valid_comments_count = 0
        @valid_comments = []

        comments.includes([:user]).each do |comment|
          break if valid_comments_count == comments_to_show

          if comment.visible_for?(current_user)
            @valid_comments << comment
            valid_comments_count += 1
          end
        end

        @valid_comments
      end

      private

      # A MD5 hash of model attributes because is needed because
      # it ensures the cache version value will always be the same size
      def cache_hash
        hash = []
        hash << "decidim/content_blocks/last_comment"
        hash << Digest::MD5.hexdigest(valid_comments.map(&:cache_key_with_version).to_s)
        hash << I18n.locale.to_s

        hash.join(Decidim.cache_key_separator)
      end

      def comments
        @comments ||= begin
          query = Decidim::LastActivity.new(
            current_organization,
            current_user:
          ).query.where(resource_type: "Decidim::Comments::Comment")

          if participatory_space_filter.present?
            query = query.where(participatory_space_filter)
          end

          query.limit(comments_to_show * 6)
        end
      end

      def comments_to_show
        options[:comments_count] || 3
      end

      def participatory_space_filter
        return if model.scoped_resource_id.blank?
        return if participatory_space_model_class_name.blank?

        {
          participatory_space_type: participatory_space_model_class_name,
          participatory_space_id: model.scoped_resource_id
        }
      end

      def participatory_space_model_class_name
        @participatory_space_model_class_name ||= Decidim.participatory_space_manifests.find do |manifest|
          manifest.content_blocks_scope_name == model.scope_name.to_s
        end&.model_class_name
      end
    end
  end
end
