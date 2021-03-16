# frozen_string_literal: true

require "active_support/concern"

module Decidim
  module UserExtension
    # Changes in methods to store user extended attributes in user profile
    module CreateOmniauthCommandsOverrides
      extend ActiveSupport::Concern

      private

      def create_or_find_user
        generated_password = SecureRandom.hex

        @user = User.find_or_initialize_by(
          email: verified_email,
          organization: organization
        )

        if @user.persisted?
          # If user has left the account unconfirmed and later on decides to sign
          # in with omniauth with an already verified account, the account needs
          # to be marked confirmed.
          @user.skip_confirmation! if !@user.confirmed? && @user.email == verified_email
        else
          @user.email = (verified_email || form.email)
          @user.name = form.name
          @user.nickname = form.normalized_nickname
          @user.newsletter_notifications_at = nil
          @user.email_on_notification = true
          @user.password = generated_password
          @user.password_confirmation = generated_password
          @user.remote_avatar_url = form.avatar_url if form.avatar_url.present?
          @user.skip_confirmation! if verified_email
        end

        @user.user_extension = form.user_extension if form.user_extension.present?
        @user.tos_agreement = "1"
        @user.save!
      end

      def trigger_omniauth_registration
        ActiveSupport::Notifications.publish(
          "decidim.user.omniauth_registration",
          user_id: @user.id,
          identity_id: @identity.id,
          provider: form.provider,
          uid: form.uid,
          email: form.email,
          name: form.name,
          nickname: form.normalized_nickname,
          avatar_url: form.avatar_url,
          raw_data: form.raw_data,
          user_extension: form.user_extension
        )
      end
    end
  end
end
