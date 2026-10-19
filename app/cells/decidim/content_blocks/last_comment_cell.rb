# frozen_string_literal: true

module Decidim
  module ContentBlocks
    # A cell to be rendered as a content block with the latest comments performed
    # in a Decidim Organization.
    class LastCommentCell < Decidim::ViewModel
      include Decidim::Core::Engine.routes.url_helpers
      include Decidim::Comments::RoutableRootCommentable

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

          if visible_comment?(comment)
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

          query = query.where(participatory_space_filter) if participatory_space_filter.present?
          query = in_published_components(query)

          query.limit(comments_to_show * 6)
        end
      end

      # Keeps only comments in published components, or in none. Comments in an
      # unpublished component must not be shown, and those in a trashed one
      # (including those of a trashed space) cannot be linked to. Dropping them
      # here rather than per comment keeps them from using up the buffer above.
      #
      # Decidim::Component's default scope leaves trashed components out. Logs
      # without a component are kept explicitly, as IN never matches NULL.
      def in_published_components(query)
        query.where(decidim_component_id: nil)
             .or(query.where(decidim_component_id: Decidim::Component.published.select(:id)))
      end

      # A comment is dropped here rather than in the activity cell, so that its
      # slot is refilled from the buffer instead of leaving a gap in the block.
      # On the landing page of an unpublished space ActionLog#visible_for? hides
      # every comment, as upstream does.
      def visible_comment?(action_log)
        linkable_comment?(action_log) && action_log.visible_for?(current_user) && visible_root_commentable?(action_log)
      end

      # Checks what ActionLog#visible_for? misses about the commented resource:
      # - it only checks the comment for moderation, not the resource;
      # - it does not check whether the resource is still published (e.g. a
      #   blog post whose publication date was moved to the future);
      # - it skips the resource check on transparent spaces, letting comments
      #   on a private meeting through.
      def visible_root_commentable?(action_log)
        root = action_log.resource_lazy.root_commentable
        return false if root.try(:hidden?)
        return false if root.respond_to?(:published?) && !root.published?
        return true unless root.respond_to?(:current_user_can_visit_meeting?)

        root.current_user_can_visit_meeting?(current_user)
      end

      # Resolving the commented resource constantizes a polymorphic type that
      # may belong to a module no longer installed. ActionLog#visible_for?
      # guards its own resolution the same way; without this we would move that
      # failure out from under its rescue and back onto the page.
      def linkable_comment?(action_log)
        routable_root_commentable?(action_log.resource_lazy.try(:root_commentable))
      rescue NameError => e
        Rails.logger.warn "Failed resource for #{action_log.class.name}(id=#{action_log.id}): #{e.message}"

        false
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
