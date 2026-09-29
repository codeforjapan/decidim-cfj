# frozen_string_literal: true

module Decidim
  module Comments
    # A cell to display when a comment has been created.
    class LastCommentActivityCell < ActivityCell
      include CommentCellsHelper
      include Decidim::RoutableRootCommentable

      # A comment whose commented resource sits in a trashed component cannot
      # be linked to, and building that link is what renders this cell. Skip it
      # rather than let it raise, which would take the surrounding page down.
      def renderable?
        super && routable_root_commentable?(root_commentable)
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
    end
  end
end
