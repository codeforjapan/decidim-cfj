# frozen_string_literal: true

require "active_support/concern"

module Decidim
  module UserExtension
    module Concerns
      module Controllers
        # A concern with the features needed when user exntesions are not registered
        module NeedsUserExtension
          extend ActiveSupport::Concern

          ALLOWS_WITHOUT_USER_EXTENSION = %w(account homepage pages tos).freeze

          included do
            before_action :needs_user_extension
          end

          private

          def needs_user_extension
            logger.info("controller_name: #{controller_name}")
            return true unless current_user
            return true if ALLOWS_WITHOUT_USER_EXTENSION.include?(controller_name)
            return true unless enable_user_extension?

            metadata = authorization_metadata

            ## TODO: validate all metadata; only exsistance now
            if !metadata["real_name"] || !metadata["address"] || !metadata["birth_year"] || !metadata["gender"]
              flash[:error] = t("errors.messages.needs_user_extension")
              redirect_to decidim.account_path
            end
          end

          def enable_user_extension?
            current_organization.available_authorizations&.include?("user_extension")
          end

          def authorization_metadata
            auth = Decidim::Authorization.find_or_initialize_by(
              user: current_user,
              name: "user_extension"
            )
            auth.attributes["metadata"] || {}
          end
        end
      end
    end
  end
end
