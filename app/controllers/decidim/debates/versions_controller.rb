# frozen_string_literal: true

module Decidim
  module Debates
    # Exposes Debates versions so users can see how a Debate has been updated
    # through time.
    class VersionsController < Decidim::Debates::ApplicationController
      include Decidim::ApplicationHelper
      include Decidim::ResourceVersionsConcern

      OBJECT_CHANGE_SIZE_LIMIT = 1_000_000

      def versioned_resource
        @versioned_resource ||= present(Debate.where(component: current_component).find(params[:debate_id]))
      end

      def show
        description = current_version.object_changes
        if description && description.size > OBJECT_CHANGE_SIZE_LIMIT
          flash[:alert] = I18n.t("debates.versions.too_large_changeset", scope: "decidim.debates")
          redirect_to action: :index
        end
      end
    end
  end
end
