# frozen_string_literal: true

module Decidim
  # Trashing a component soft-deletes it, so the resources inside it stop being
  # routable: their `component` starts returning nil and the route helpers fall
  # back to calling `mounted_engine` on the resource itself, which only
  # components and participatory spaces implement.
  #
  # Comments and their action logs survive the trashing of the component their
  # commented resource lives in. Both the content block that collects those
  # comments and the cell that renders them have to recognise them, otherwise
  # the content block reserves a slot for a comment that renders nothing.
  module RoutableRootCommentable
    private

    def routable_root_commentable?(commentable)
      return false if commentable.blank?
      # Participatory spaces route themselves rather than through a component.
      return true if commentable.respond_to?(:mounted_engine)

      commentable.try(:component).present?
    end
  end
end
