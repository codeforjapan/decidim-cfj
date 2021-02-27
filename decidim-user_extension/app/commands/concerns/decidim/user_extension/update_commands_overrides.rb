# frozen_string_literal: true

require "active_support/concern"

module Decidim
  module UserExtension
    # Changes in methods to store user extended attributes in user profile
    module UpdateCommandsOverrides
      extend ActiveSupport::Concern

      def call
        return broadcast(:invalid) unless @form.valid?

        update_personal_data
        update_avatar
        update_password
        update_user_extension

        if @user.valid?
          @user.save!
          notify_followers
          broadcast(:ok, @user.unconfirmed_email.present?)
        else
          @form.errors.add :avatar, @user.errors[:avatar] if @user.errors.has_key? :avatar
          broadcast(:invalid)
        end
      end

      private

      def update_user_extension
        # ignore if user_extension is disable
        return unless current_organization.available_authorization_handlers&.include?("user_extension_authorization_handler")

        user_extension = @form.user_extension
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
