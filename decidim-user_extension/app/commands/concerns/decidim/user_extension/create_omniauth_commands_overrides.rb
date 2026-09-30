# frozen_string_literal: true

require "active_support/concern"

module Decidim
  module UserExtension
    # Changes in methods to store user extended attributes in user profile
    module CreateOmniauthCommandsOverrides
      extend ActiveSupport::Concern

      private

      # 本体の create_or_find_user をそのまま活かし（名前サニタイズ・ToS 同意の
      # 強制など Decidim 側の挙動を維持したまま）、user_extension だけを追加で永続化する。
      def create_or_find_user
        super
        update_user_extension if form.user_extension.present?
      end

      def update_user_extension
        @user.update!(user_extension: form.user_extension)
      end

      # 本体の attach_avatar は avatar_url を url.open で直接取得するため SSRF に対して
      # 無防備。プライベート IP 遮断・サイズ/リダイレクト制限付きの AvatarFetcher で上書きする。
      def attach_avatar(avatar_url)
        return if avatar_url.blank?

        io, filename = Decidim::UserExtension::AvatarFetcher.call(avatar_url)
        unless io
          Rails.logger.info { "[Decidim::UserExtension] avatar not attached for #{@user.email}" }
          return
        end

        @user.avatar.attach(io:, filename:)
      end
    end
  end
end
