# frozen_string_literal: true

# 管理画面の CSV 一括登録（Decidim::Admin::BulkUserImportsController）を Decidim に差し込む。
#
# ルートは to_prepare ではなく初期化時に一度だけ append している。
# RouteSet#append に積んだブロックはルートのリロード（RouteSet#clear!）では捨てられないため、
# 開発環境でリクエストごとに走る to_prepare に置くとリロードのたびに同じルートが積み増され、
# `rails routes` に何本も現れてしまう。ルート定義は再読み込み対象の定数を参照しないので、
# 起動時に一度だけ登録すれば十分。
#
# コアの管理画面ルートを包む OrganizationDashboardConstraint は使っていない。制約を外れた場合の
# 結果はルート不一致（404）で、非管理者に「権限がありません」を返せないため、認可は
# Decidim::BulkUserImportPermissions に一本化している。
Decidim::Admin::Engine.routes.append do
  resource :bulk_user_import, only: [:new, :create], controller: "/decidim/admin/bulk_user_imports"
end

# メニューのアイコンは Decidim のアイコンレジストリに登録されているものしか使えない
# （未登録だと development / test で例外になる）。remixicon には存在するがコアが登録していないため、ここで登録する。
Decidim.icons.register(name: "upload-2-line", icon: "upload-2-line", category: "system",
                       description: "", engine: :decidim_cfj)

# 「参加者」セクションのメニュー。ブロックはレンダリング時にビューのコンテキストで評価される。
Decidim.menu :admin_user_menu do |menu|
  menu.add_item :bulk_user_imports,
                I18n.t("menu.bulk_user_imports", scope: "decidim.admin"),
                decidim_admin.new_bulk_user_import_path,
                icon_name: "upload-2-line",
                active: is_active_link?(decidim_admin.new_bulk_user_import_path),
                if: current_user&.admin?
end
