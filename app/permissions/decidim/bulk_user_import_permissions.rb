# frozen_string_literal: true

module Decidim
  # 管理画面の CSV 一括登録（Decidim::Admin::BulkUserImportsController）の権限。
  #
  # :bulk_user_import はこのリポジトリ独自のリソースで、コアの
  # Decidim::Admin::Permissions は未知の subject に対して状態を設定しない
  # （= PermissionNotSetError となり、組織 admin であっても弾かれる）。
  # そのためチェーンにはこのクラスだけを登録し、必ず allow!/disallow! のどちらかを
  # 確定させることで「組織 admin 限定」という判定を一箇所に閉じ込めている。
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
