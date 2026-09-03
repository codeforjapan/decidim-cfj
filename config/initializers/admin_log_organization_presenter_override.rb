# frozen_string_literal: true

# 管理ログで CSV 一括登録（action: "bulk_user_import"）の行を専用の文言で表示する。
#
# ActionLog の presenter は resource のクラスから引かれる。一括登録は組織を resource として
# 記録しているため Decidim::AdminLog::OrganizationPresenter が使われるが、そのままだと未知の
# action が「組織を更新しました」として表示されてしまうので、この action だけ差し替える。
Rails.application.config.to_prepare do
  module DecidimAdminLogOrganizationPresenterBulkUserImportPatch
    BULK_USER_IMPORT_ACTION = "bulk_user_import"

    private

    def action_string
      return "decidim.admin_log.organization.bulk_user_import" if action.to_s == BULK_USER_IMPORT_ACTION

      super
    end

    def i18n_params
      return super unless action.to_s == BULK_USER_IMPORT_ACTION

      super.merge(
        created: action_log.extra["created"].to_i,
        skipped: action_log.extra["skipped"].to_i,
        failed: action_log.extra["failed"].to_i
      )
    end
  end

  Decidim::AdminLog::OrganizationPresenter.prepend(DecidimAdminLogOrganizationPresenterBulkUserImportPatch)
end
