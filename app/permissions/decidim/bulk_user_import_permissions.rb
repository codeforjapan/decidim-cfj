# frozen_string_literal: true

module Decidim
  # 管理画面の CSV 一括登録（Decidim::Admin::BulkUserImportsController）の権限。
  #
  # :bulk_user_import はこのリポジトリ独自の subject で、コアの権限クラスはどれも状態を
  # 設定しないため、このクラスが判定を確定させる。スペース管理者には開放しない。
  class BulkUserImportPermissions < Decidim::DefaultPermissions
    def permissions
      return permission_action unless permission_action.scope == :admin
      return permission_action unless permission_action.subject == :bulk_user_import

      toggle_allow(organization_admin?)

      permission_action
    end

    private

    # 他組織のユーザーを作らせないため、ログイン中の組織の admin であることまで確認する。
    def organization_admin?
      return false if user.blank?
      return false unless user.admin?
      return false unless user.admin_terms_accepted?

      current_organization.present? && user.organization == current_organization
    end

    def current_organization
      context[:current_organization]
    end
  end
end
