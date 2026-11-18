# frozen_string_literal: true

# Renders comments whose author record no longer exists as authored by a
# deleted participant instead of raising on the nil author.
Rails.application.config.to_prepare do
  module DecidimCommentCellMissingAuthorPatch
    def perform_caching?
      model.author.present? && super
    end

    private

    def author_presenter
      return Decidim::NilPresenter.new if model.author.nil?

      super
    end
  end

  module DecidimCommentMissingAuthorPatch
    # `user == author` is true for a visitor who is not signed in when the
    # author is missing, which shows the edit and delete actions to them.
    def authored_by?(user)
      user.present? && super
    end

    # Called when the comment is reported.
    def reported_searchable_content_extras
      return [] if author.nil?

      super
    end
  end

  Decidim::Comments::CommentCell.prepend(DecidimCommentCellMissingAuthorPatch)
  Decidim::Comments::Comment.prepend(DecidimCommentMissingAuthorPatch)
end
