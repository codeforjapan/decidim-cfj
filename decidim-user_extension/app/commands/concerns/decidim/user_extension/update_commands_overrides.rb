# frozen_string_literal: true

require "active_support/concern"

module Decidim
  module UserExtension
    # Changes in methods to store user extended attributes in user profile
    module UpdateCommandsOverrides
      extend ActiveSupport::Concern

      def call
        return broadcast(:invalid, @form.password) unless @form.valid?

        update_personal_data
        update_avatar
        update_password
        update_user_extension

        if current_user.valid?
          changes = current_user.changed
          current_user.save!
          notify_followers
          send_update_summary!(changes)
          broadcast(:ok, current_user.unconfirmed_email.present?)
        else
          [:avatar, :password].each do |key|
            @form.errors.add key, current_user.errors[key] if current_user.errors.has_key? key
          end
          broadcast(:invalid, @form.password)
        end
      end

      private

      def update_user_extension
        # ignore if user_extension is disable
        return unless current_organization&.available_authorizations&.include?("user_extension")

        # ユーザーが存在しない場合は処理をスキップ
        return unless current_user&.persisted?

        # フォームまたはuser_extensionが存在しない場合はスキップ
        return unless @form&.user_extension

        user_extension = @form.user_extension
        auth = authorization
        return unless auth # authorizationが取得できない場合はスキップ

        auth.attributes = {
          unique_id: user_extension.unique_id,
          metadata: {
            "real_name" => user_extension.real_name,
            "address" => user_extension.address,
            "birth_year" => user_extension.birth_year,
            "gender" => user_extension.gender,
            "occupation" => user_extension.occupation
          }
        }
        auth.save!
      end

      def authorization
        @authorization ||= Decidim::Authorization.find_or_initialize_by(
          user: current_user,
          name: "user_extension"
        )
      end
    end
  end
end
