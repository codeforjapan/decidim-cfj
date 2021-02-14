# frozen_string_literal: true

require "active_support/concern"

module Decidim
  module UserExtension
    # Changes in methods to store user extended attributes in user profile
    module CreateCommandsOverrides
      extend ActiveSupport::Concern

      # Executes the command. Broadcasts these events:
      #
      # - :ok when everything is valid.
      # - :invalid if the form wasn't valid and we couldn't proceed.
      #
      # Returns nothing.
      def call
        if form.invalid?
          user = User.has_pending_invitations?(form.current_organization.id, form.email)
          user.invite!(user.invited_by) if user
          return broadcast(:invalid)
        end

        transaction do
          create_user
          create_user_extension
        end

        broadcast(:ok, @user)
      rescue ActiveRecord::RecordInvalid
        broadcast(:invalid)
      end

      private

      def create_user_extension
        user_extension = form.user_extension
        authorization.attributes = {
          unique_id: user_extension.unique_id,
          metadata: {
            "real_name" => user_extension.real_name,
            "address" => user_extension.address,
            "birth_year" => user_extension.birth_year,
            "gender" => user_extension.gender,
            "occupation" => user_extension.occupation
          }
        }
        authorization.save!
      end

      def authorization
        @authorization ||= Decidim::Authorization.find_or_initialize_by(
          user: @user,
          name: "user_extension"
        )
      end
    end
  end
end
