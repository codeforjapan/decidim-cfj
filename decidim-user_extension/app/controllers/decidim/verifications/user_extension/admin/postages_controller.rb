# frozen_string_literal: true

module Decidim
  module Verifications
    module UserExtension
      module Admin
        #
        # Handles postages for verification letters.
        #
        class PostagesController < Decidim::Admin::ApplicationController
          layout "decidim/admin/users"

          before_action :load_pending_authorization

          def create
            enforce_permission_to :update, :authorization, authorization: @pending_authorization

            @form = PostageForm.from_model(@pending_authorization)

            PerformAuthorizationStep.call(@pending_authorization, @form) do
              on(:ok) do
                flash[:notice] = t("postages.create.success", scope: "decidim.verifications.user_extension.admin")
                redirect_to pending_authorizations_path
              end

              on(:invalid) do
                render json: { error: I18n.t("postages.create.error", scope: "decidim.verifications.user_extension.admin") }, status: :unprocessable_entity
              end
            end
          end

          private

          def load_pending_authorization
            @pending_authorization = Authorization.find(params[:pending_authorization_id])
          end
        end
      end
    end
  end
end
