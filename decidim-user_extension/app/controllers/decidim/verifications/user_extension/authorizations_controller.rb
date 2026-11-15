# frozen_string_literal: true

module Decidim
  module Verifications
    module UserExtension
      # The user_extension authorization is created and updated from the
      # registration and account forms, and stays pending. This controller only
      # serves the information page that the authorizations list, the
      # authorization modal and the onboarding page link to.
      class AuthorizationsController < ApplicationController
        include Decidim::Verifications::Renewable

        before_action :load_authorization

        def new
          enforce_permission_to :create, :authorization, authorization: @authorization
        end

        def edit
          enforce_permission_to :update, :authorization, authorization: @authorization

          render :new
        end

        private

        def authorization
          @authorization_presenter ||= AuthorizationPresenter.new(@authorization)
        end

        def load_authorization
          @authorization = Decidim::Authorization.find_or_initialize_by(
            user: current_user,
            name: "user_extension"
          )
        end
      end
    end
  end
end
