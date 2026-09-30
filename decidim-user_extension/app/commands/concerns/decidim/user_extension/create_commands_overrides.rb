# frozen_string_literal: true

require "active_support/concern"

module Decidim
  module UserExtension
    # Changes in methods to store user extended attributes in user profile
    module CreateCommandsOverrides
      extend ActiveSupport::Concern

      private

      # 本体の create_user に続けて user_extension(authorization)を作成する。
      # call を再現しないことで CreateRegistration の 0.31 挙動を維持しつつ、
      # ユーザーと user_extension の作成を同一トランザクションで原子的に行う。
      def create_user
        transaction do
          super
          create_user_extension
        end
      end

      def create_user_extension
        # ignore if user_extension is disable
        return unless current_organization.available_authorizations&.include?("user_extension")

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
