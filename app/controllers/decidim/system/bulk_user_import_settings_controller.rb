# frozen_string_literal: true

module Decidim
  module System
    # /system から組織ごとの一括アカウント発行設定（有効フラグ・ダミーメールのドメイン）を編集する。
    # 認証はルート側の authenticate(:admin)（システム管理者）で行われる。
    class BulkUserImportSettingsController < Decidim::System::ApplicationController
      def index
        @organizations = Decidim::Organization.order(:id)
        @settings_by_organization = Decidim::BulkUserImportSetting.all.index_by(&:decidim_organization_id)
      end

      def edit
        @organization = Decidim::Organization.find(params[:organization_id])
        @setting = setting_for(@organization)
      end

      def update
        @organization = Decidim::Organization.find(params[:organization_id])
        @setting = setting_for(@organization)
        @setting.assign_attributes(setting_params)

        if @setting.save
          flash[:notice] = t("update.success", scope: "decidim.system.bulk_user_import_settings")
          redirect_to bulk_user_import_settings_path
        else
          flash.now[:alert] = t("update.error", scope: "decidim.system.bulk_user_import_settings")
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def setting_for(organization)
        Decidim::BulkUserImportSetting.find_or_initialize_by(decidim_organization_id: organization.id)
      end

      def setting_params
        params.require(:bulk_user_import_setting).permit(:email_domain, :enabled)
      end
    end
  end
end
