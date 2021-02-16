# frozen_string_literal: true

module Decidim
  module UserExtension
    module Admin
      module Officializations
        class UserExtensionsController < Decidim::UserExtension::Admin::ApplicationController
          include Decidim::Admin::Officializations::Filterable

          helper_method :user

          def show
            enforce_permission_to :show_user_extension, :user, user: user

            Decidim.traceability.perform_action! :show_user_extension, user, current_user

            @user_extension = user_extension

            render :show, layout: false
          end

          private

          def user
            @user ||= Decidim::User.find_by(
              id: params[:user_id],
              organization: current_organization
            )
          end

          def user_extension
            @authorization = Authorization.find_by(
              decidim_user_id: user.id,
              name: "user_extension"
            )
            @authorization&.metadata || {}
          end
        end
      end
    end
  end
end
