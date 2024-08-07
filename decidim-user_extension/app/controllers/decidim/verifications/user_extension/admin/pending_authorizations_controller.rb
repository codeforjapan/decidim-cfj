# frozen_string_literal: true

module Decidim
  module Verifications
    module UserExtension
      module Admin
        class PendingAuthorizationsController < Decidim::Admin::ApplicationController
          layout "decidim/admin/users"

          def index
            enforce_permission_to :index, :authorization

            @pending_authorizations = AuthorizationPresenter.for_collection(
              pending_authorizations
            )
          end

          private

          def pending_authorizations
            Authorizations.new(organization: current_organization, name: "user_extension", granted: false)
          end
        end
      end
    end
  end
end
