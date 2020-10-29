# frozen_string_literal: true

module Decidim
  module Admin
    module Officializations
      class UserExtensionsController < Decidim::Admin::ApplicationController
        include Decidim::Admin::Officializations::Filterable

        helper_method :user

        def show
          enforce_permission_to :show_user_extension, :user, user: user

          Decidim.traceability.perform_action! :show_user_extension, user, current_user

          read_authorization

          render :show, layout: false
        end

        private

        def user
          @user ||= Decidim::User.find_by(
            id: params[:user_id],
            organization: current_organization
          )
        end

        def read_authorization
          @authorization = Authorization.find_by(
            decidim_user_id: user.id,
            name: "user_extension"
          )
          @user_extension = @authorization.metadata
        end
      end
    end
  end
end
