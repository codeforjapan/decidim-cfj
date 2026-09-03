# frozen_string_literal: true

# 参加スペース単位の一括アカウント発行（Decidim::BulkSpaceAccountIssuer）のUIを差し込む。
#
# - /system: 組織ごとの設定（有効フラグ・ダミーメールのドメイン）を編集する専用ページ。
#   コアの組織編集フォームには手を入れない（フォーム/コマンド/ビューへのパッチはバージョン
#   アップで壊れやすいため、自前のページで完結させる）。
# - 管理画面: 各アセンブリのサイドメニューに「アカウント一括発行」を追加。
#   組織の設定が有効 かつ スペースが非公開（private_space）のときだけ表示する。
#
# ルートを to_prepare ではなく初期化時に一度だけ append する理由は
# bulk_user_import.rb（#866）と同じ: ルート定義は再読み込み対象の定数を参照しない。
Decidim::System::Engine.routes.append do
  authenticate(:admin) do
    resources :bulk_user_import_settings,
              param: :organization_id,
              only: [:index, :edit, :update],
              controller: "/decidim/system/bulk_user_import_settings"
  end
end

# コアの管理画面ルートを包む OrganizationDashboardConstraint はあえて使わない。
# 制約を外れた場合の結果がルート不一致（404）になり、権限が無い相手に
# 「権限がありません」を返せないため。認可は BulkAccountIssuePermissions に一本化する。
Decidim::Assemblies::AdminEngine.routes.append do
  resources :assemblies, param: :slug, only: [] do
    resource :bulk_account_issue,
             only: [:new, :create],
             controller: "/decidim/assemblies/admin/bulk_account_issues"
  end
end

# remixicon には存在するがコアが登録していないアイコンは明示登録が必要（未登録だと dev/test で例外）。
Decidim.icons.register(name: "user-add-line", icon: "user-add-line", category: "system",
                       description: "", engine: :decidim_cfj)

# /system のサイドメニュー。
Decidim.menu :system_menu do |menu|
  menu.add_item :bulk_user_import_settings,
                I18n.t("menu.bulk_user_import_settings", scope: "decidim.system"),
                decidim_system.bulk_user_import_settings_path,
                position: 4.5,
                active: :inclusive
end

# アセンブリ管理画面のサイドメニュー。ブロックはレンダリング時にビューのコンテキストで評価される。
# 権限チェーンはコントローラ側の専用クラスに任せ、ここでは表示条件だけを見る。
#
# 表示条件（MVP）: /system でこの組織の発行が有効 かつ このスペースが非公開、の両方を
# 満たす場合のみ。将来別ケースに広げる場合もこの条件式に足す。
#
# 注意: MenuItem#visible? は if: が nil のとき「条件指定なし＝表示」と解釈する。
# find_by(...)&.enabled? のような式は設定レコードが無い組織で nil になり、
# 未設定の組織（マルチテナントの他組織を含む）に全表示される事故につながるため、
# 各項を必ず true/false に確定させること。
Decidim.menu :admin_assembly_menu do |menu|
  issuing_available = current_user.present? && current_user.admin? &&
                      current_participatory_space.private_space? &&
                      Decidim::BulkUserImportSetting.exists?(decidim_organization_id: current_organization.id,
                                                             enabled: true)

  menu.add_item :bulk_account_issue,
                I18n.t("menu.bulk_account_issue", scope: "decidim.admin"),
                decidim_admin_assemblies.new_assembly_bulk_account_issue_path(current_participatory_space),
                icon_name: "user-add-line",
                active: is_active_link?(decidim_admin_assemblies.new_assembly_bulk_account_issue_path(current_participatory_space)),
                if: issuing_available
end

# 管理ログで一括発行（action: "bulk_account_issue"）の行を専用の文言で表示する。
# resource はアセンブリなので AssemblyPresenter が使われる。未知の action のままだと
# 「Assembly を更新しました」相当の文言になってしまうため、この action だけ差し替える。
Rails.application.config.to_prepare do
  module DecidimAssemblyPresenterBulkAccountIssuePatch
    BULK_ACCOUNT_ISSUE_ACTION = "bulk_account_issue"

    private

    def action_string
      return "decidim.admin_log.assembly.bulk_account_issue" if action.to_s == BULK_ACCOUNT_ISSUE_ACTION

      super
    end

    def i18n_params
      return super unless action.to_s == BULK_ACCOUNT_ISSUE_ACTION

      super.merge(
        created: action_log.extra["created"].to_i,
        failed: action_log.extra["failed"].to_i
      )
    end
  end

  Decidim::Assemblies::AdminLog::AssemblyPresenter.prepend(DecidimAssemblyPresenterBulkAccountIssuePatch)
end
