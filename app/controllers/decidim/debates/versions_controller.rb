# frozen_string_literal: true

module Decidim
  module Debates
    # Exposes Debates versions so users can see how a Debate has been updated
    # through time.
    class VersionsController < Decidim::Debates::ApplicationController
      include Decidim::ApplicationHelper
      include Decidim::ResourceVersionsConcern

      # cfj 独自: object_changes が巨大な版は描画に耐えられないため一覧へ戻す。
      OBJECT_CHANGE_SIZE_LIMIT = 1_000_000

      def versioned_resource
        @versioned_resource ||= Debate.where(component: current_component).not_hidden.find(params[:debate_id])
      end

      def add_breadcrumb_item
        return {} if versioned_resource.blank?

        {
          label: translated_attribute(versioned_resource.title),
          url: Decidim::EngineRouter.main_proxy(current_component).debate_path(versioned_resource),
          active: false
        }
      end

      # cfj 独自
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
