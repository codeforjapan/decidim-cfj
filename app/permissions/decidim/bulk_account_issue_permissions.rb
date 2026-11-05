# frozen_string_literal: true

module Decidim
  # アセンブリ管理画面の一括アカウント発行（Decidim::Assemblies::Admin::BulkAccountIssuesController）の権限。
  #
  # このクラスの役割は以下の2点になる。
  #
  # 1. :bulk_account_issue はこのリポジトリ独自の subject で、コアの権限クラスはどれも状態を
  #    設定しない。未設定のままだと allowed_to? が false を返す（PermissionNotSetError を
  #    rescue しているため）ので、誰も発行できない。このクラスが判定を確定させる。
  # 2. この画面を組織 admin に限定する。スペース管理者には開放しない。
  class BulkAccountIssuePermissions < Decidim::DefaultPermissions
    def permissions
      return permission_action unless permission_action.scope == :admin

      # :read :participatory_space は AssemblyAdmin の participatory_space_admin_layout が
      # before_action で強制する読み取り権限。コアはスペース管理者にも許可するので、ここで
      # 組織 admin だけに絞り直す。これがこの画面の入口を塞ぐ判定になる。
      case [permission_action.action, permission_action.subject]
      when [:read, :participatory_space], [:create, :bulk_account_issue]
        toggle_allow(organization_admin?)
      end

      permission_action
    end

    private

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
