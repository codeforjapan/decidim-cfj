# frozen_string_literal: true

module Decidim
  module Comments
    # A cell to display when a comment has been created.
    class LastCommentActivityCell < ActivityCell
      include CommentCellsHelper

      def show
        return unless renderable?

        render
      end

      # Trashing a component soft-deletes it, so the resources inside it stop
      # being routable: `root_commentable.component` starts returning nil and
      # the route helpers fall back to calling `mounted_engine` on the resource
      # itself, which only components and participatory spaces implement.
      #
      # The comment and its action log survive the trashing, so those comments
      # still reach this cell. Skipping them keeps the surrounding page alive
      # instead of raising NoMethodError while building the link.
      def renderable?
        super && routable_root_commentable?
      end

      def title
        I18n.t("decidim.comments.last_activity.new_comment")
      end

      def participatory_space
        model.participatory_space_lazy
      end

      def participatory_space_link
        link_to(root_commentable_title, resource_link_path)
      end

      def participatory_space_icon
        resource_type_icon(root_commentable.class)
      end

      def hide_participatory_space? = false

      def comment
        model.resource_lazy
      end

      def max_comment_length
        40
      end

      private

      # Participatory spaces route themselves; everything else is routed
      # through its component, which is gone once the component is trashed.
      def routable_root_commentable?
        return true if root_commentable.respond_to?(:mounted_engine)

        root_commentable.try(:component).present?
      end
    end
  end
end
