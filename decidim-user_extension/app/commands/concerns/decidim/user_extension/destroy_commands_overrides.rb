# frozen_string_literal: true

require "active_support/concern"

module Decidim
  module UserExtension
    # Changes in methods to store user extended attributes in user profile
    module DestroyCommandsOverrides
      extend ActiveSupport::Concern

      def call
        return broadcast(:invalid) unless @form.valid?

        Decidim::User.transaction do
          destroy_user_account!
          destroy_user_identities
          destroy_user_group_memberships
          destroy_follows
          destroy_participatory_space_private_user
          delegate_destroy_to_participatory_spaces
          destroy_user_extension
        end

        broadcast(:ok)
      end

      private

      def destroy_user_extension
        authorization = Decidim::Authorization.find_by(
          user: @user,
          name: "user_extension"
        )
        # should be removed privacy data even if current_organization.available_authorization_handlers is empty
        if authorization
          authorization.attributes = {
            unique_id: nil,
            metadata: {}
          }
          authorization.save!
        end
      end
    end
  end
end
