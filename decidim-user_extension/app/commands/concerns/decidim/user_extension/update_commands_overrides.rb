# frozen_string_literal: true

require "active_support/concern"

module Decidim
  module UserExtension
    # Changes in methods to store user extended attributes in user profile
    module UpdateCommandsOverrides
      extend ActiveSupport::Concern

      private

      # 本体の update_personal_data に続けて user_extension を保存する。
      # call を再現しないことで、0.31 の with_events による更新イベント発行を維持する。
      def update_personal_data
        super
        update_user_extension
      end

      def update_user_extension
        # ignore if user_extension is disable
        return unless current_organization.available_authorizations&.include?("user_extension")

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
          user: current_user,
          name: "user_extension"
        )
      end
    end
  end
end
