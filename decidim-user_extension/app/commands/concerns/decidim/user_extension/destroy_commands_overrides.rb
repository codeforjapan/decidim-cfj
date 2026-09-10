# frozen_string_literal: true

require "active_support/concern"

module Decidim
  module UserExtension
    # Changes in methods to store user extended attributes in user profile
    module DestroyCommandsOverrides
      extend ActiveSupport::Concern

      private

      # 本体の destroy_user_account! に続けて user_extension の個人情報を消去する。
      # Decidim 0.31 の DestroyAccount は authorization を cascade 削除しないため、
      # 実名・住所などの個人情報を明示的にスクラブする必要がある。
      # call を再現しないことで、0.31 で追加された各種削除処理を取りこぼさない。
      def destroy_user_account!
        super
        destroy_user_extension
      end

      def destroy_user_extension
        authorization = Decidim::Authorization.find_by(
          user: current_user,
          name: "user_extension"
        )
        return unless authorization

        # available_authorizations が空でも個人情報は必ず消去する
        authorization.attributes = {
          unique_id: nil,
          metadata: {}
        }
        authorization.save!
      end
    end
  end
end
