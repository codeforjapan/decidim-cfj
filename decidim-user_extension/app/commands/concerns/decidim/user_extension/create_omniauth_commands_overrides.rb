# frozen_string_literal: true

require "active_support/concern"

module Decidim
  module UserExtension
    # Changes in methods to store user extended attributes in user profile
    module CreateOmniauthCommandsOverrides
      extend ActiveSupport::Concern

      private

      def create_or_find_user
        @user = User.find_or_initialize_by(
          email: verified_email,
          organization:
        )

        if @user.persisted?
          # If user has left the account unconfirmed and later on decides to sign
          # in with omniauth with an already verified account, the account needs
          # to be marked confirmed.
          update_existing_user
        else
          create_new_user
        end

        update_user_extension if form.user_extension.present?
      end

      def update_existing_user
        if !@user.confirmed? && @user.email == verified_email
          @user.skip_confirmation!
          @user.after_confirmation
        end
        @user.tos_agreement = "1"
        @user.save!
      end

      def create_new_user
        @user.email = (verified_email || form.email)
        @user.name = form.name
        @user.nickname = form.normalized_nickname
        @user.newsletter_notifications_at = nil
        @user.password = SecureRandom.hex
        if form.avatar_url.present?
          url = URI.parse(form.avatar_url)
          filename = File.basename(url.path)
          file = url.open
          @user.avatar.attach(io: file, filename:)
        end
        @user.skip_confirmation! if verified_email
        @user.tos_agreement = "1"
        @user.save!

        @user.after_confirmation if verified_email
      end

      def update_user_extension
        @user.update!(user_extension: form.user_extension)
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
