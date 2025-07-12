# frozen_string_literal: true

module Decidim
  # Override Decidim's EditorImagesController to fix signature URL issue
  # This controller fixes the problem where uploaded images in admin rich text editors
  # get stored with signed URLs that expire, causing images to disappear over time.
  class EditorImagesController < Decidim::ApplicationController
    include FormFactory

    # overwrite original rescue_from to ensure we print messages from ajax methods (update)
    rescue_from Decidim::ActionForbidden, with: :ajax_user_has_no_permission

    def create
      enforce_permission_to :create, :editor_image

      @form = form(EditorImageForm).from_params(form_values)

      CreateEditorImage.call(@form) do
        on(:ok) do |image|
          # Use permanent Rails blob URL instead of signed URL to prevent image expiration
          permanent_url = Rails.application.routes.url_helpers.rails_blob_url(
            image.file.blob,
            only_path: true
          )

          render json: { url: permanent_url, message: I18n.t("success", scope: "decidim.editor_images.create") }
        end

        on(:invalid) do |_message|
          render json: { message: I18n.t("error", scope: "decidim.editor_images.create") }, status: :unprocessable_entity
        end
      end
    end

    private

    # Rescue ajax calls and print the update.js view which prints the info on the message ajax form
    # Only if the request is AJAX, otherwise behave as Decidim standards
    def ajax_user_has_no_permission
      return user_has_no_permission unless request.xhr?

      render json: { message: I18n.t("actions.unauthorized", scope: "decidim.core") }, status: :unprocessable_entity
    end

    def form_values
      {
        file: params[:image],
        author_id: current_user.id
      }
    end

    def permission_scope
      :admin
    end
  end
end
