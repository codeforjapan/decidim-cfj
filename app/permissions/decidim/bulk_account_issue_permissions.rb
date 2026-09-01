# frozen_string_literal: true

module Decidim
  # アセンブリ管理画面の一括アカウント発行（Decidim::Assemblies::Admin::BulkAccountIssuesController）の権限。
  #
  # :bulk_account_issue はこのリポジトリ独自のリソースで、コアの権限クラスは未知の subject に
  # 状態を設定しない（= PermissionNotSetError で組織 admin でも弾かれる）。そのためコントローラの
  # チェーンにはこのクラスだけを登録し、必ず allow!/disallow! を確定させる。
  #
  # アカウント作成は組織レベルの権限と整理し、組織 admin に限定する（スペース管理者には開放しない。
  # 開放するとスペース管理者が自分のスペースの管理者アカウントを自増できるため、広げる場合は要議論）。
  class BulkAccountIssuePermissions < Decidim::DefaultPermissions
    def permissions
      return permission_action unless permission_action.scope == :admin

      # :read :participatory_space は AssemblyAdmin の participatory_space_admin_layout が
      # before_action で強制する読み取り権限。専用チェーンに差し替えているため、ここで
      # 明示的に判定しないと組織 admin でも弾かれる。
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
