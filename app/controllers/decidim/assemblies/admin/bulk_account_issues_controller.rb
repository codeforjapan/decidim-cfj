# frozen_string_literal: true

require "csv"

module Decidim
  module Assemblies
    module Admin
      # 各アセンブリの管理画面から、匿名IDの確定アカウントを一括発行する。
      # スペースはURL（:assembly_slug）から確定するため、入力は「参加者数・管理者数」だけ。
      # （詳細は docs/BULK_SPACE_ACCOUNTS.md）。
      #
      # 同期処理のため1回の発行数に上限を設けている。超える場合は複数回に分けるか rake を使う。
      class BulkAccountIssuesController < Decidim::Assemblies::Admin::ApplicationController
        include Concerns::AssemblyAdmin

        # AssemblyAdmin と同じコアのクラスに、独自リソース用のクラスを足したチェーン。
        #
        # サイドメニューの各項目は allowed_to?(:read, :component, ...) のようにコアの権限を問い、
        # 未設定は不許可として扱われる（NeedsPermission#allowed_to? が PermissionNotSetError を
        # rescue して false を返す）。コアのクラスを外すとこの画面だけメニューが消えるため、
        # 専用クラスだけに差し替えてはいけない。
        #
        # 独自の :bulk_account_issue はコアのどのクラスも状態を設定しないので、最後に置いた
        # BulkAccountIssuePermissions が確定させる。逆にコアの subject には手を出さない。
        register_permissions(::Decidim::Assemblies::Admin::BulkAccountIssuesController,
                             ::Decidim::Assemblies::Permissions,
                             ::Decidim::Admin::Permissions,
                             ::Decidim::BulkAccountIssuePermissions)

        UTF8_BOM = "\xEF\xBB\xBF"

        helper_method :settings, :max_accounts, :slug_too_long?, :next_account_ids

        def new
          enforce_permission_to(:create, :bulk_account_issue)
          redirect_unless_available

          @form = form(BulkAccountIssueForm).instance
        end

        def create
          enforce_permission_to(:create, :bulk_account_issue)
          return if redirect_unless_available

          @form = form(BulkAccountIssueForm).from_params(params)
          return render(:new, status: :unprocessable_entity) if @form.invalid?

          results = issuer.issue(@form.instructions)
          log_issue(results)

          send_data results_csv(results),
                    type: "text/csv; charset=utf-8",
                    filename: "issued_accounts_#{Time.current.strftime("%Y%m%d%H%M%S")}.csv",
                    disposition: "attachment"
        rescue Decidim::BulkSpaceAccountIssuer::Busy
          flash.now[:alert] = t("create.errors.busy", scope: "decidim.assemblies.admin.bulk_account_issues")
          render :new, status: :unprocessable_entity
        rescue ArgumentError => e
          # BulkSpaceAccountIssuer#validate! の検証エラー（原則ここには来ない: Form の検証で先に弾く）
          flash.now[:alert] = e.message
          render :new, status: :unprocessable_entity
        end

        private

        # 上で登録したチェーンを使う（AssemblyAdmin concern の chain_for(AssemblyAdmin) を
        # 上書きする。include より後に定義しているのでこちらが勝つ）。
        def permission_class_chain
          ::Decidim.permissions_registry.chain_for(::Decidim::Assemblies::Admin::BulkAccountIssuesController)
        end

        # 権限が無かったときの戻り先。コアの既定 decidim_admin.root_path は
        # OrganizationDashboardConstraint の内側にあり、そこへ入れない相手を送ると別エンジンの
        # 相対 redirect に拾われて Routing Error になる（#866 と同じ理由）。
        def user_has_no_permission_path
          return decidim.new_user_session_path if current_user.blank?
          return decidim_admin.root_path if admin_dashboard_allowed?

          decidim.root_path
        end
        alias user_not_authorized_path user_has_no_permission_path

        def admin_dashboard_allowed?
          current_user.organization == current_organization &&
            allowed_to?(:read, :admin_dashboard, {}, [::Decidim::Admin::Permissions])
        end

        # メニューを出さない状態（設定OFF・公開スペース）への直接アクセスは、理由を添えて一覧へ戻す。
        # 戻り値 truthy = リダイレクト済み。
        def redirect_unless_available
          reason =
            if !settings&.enabled? || settings.email_domain.blank?
              :not_enabled
            elsif !current_assembly.private_space?
              :not_private
            end
          return false unless reason

          flash[:alert] = t("unavailable.#{reason}", scope: "decidim.assemblies.admin.bulk_account_issues")
          redirect_to decidim_admin_assemblies.assemblies_path
        end

        def settings
          @settings ||= Decidim::BulkUserImportSetting.find_by(decidim_organization_id: current_organization.id)
        end

        def max_accounts
          BulkAccountIssueForm::MAX_ACCOUNTS_PER_REQUEST
        end

        def slug_too_long?
          current_assembly.slug.downcase.length > Decidim::BulkSpaceAccountIssuer::MAX_SLUG_LENGTH
        end

        # 次に採番されるID（形式ごと）。
        def next_account_ids
          @next_account_ids ||= Decidim::BulkSpaceAccountIssuer.preview_account_ids(
            organization: current_organization,
            email_domain: settings.email_domain,
            space_type: "assemblies",
            space_slug: current_assembly.slug
          )
        end

        def issuer
          Decidim::BulkSpaceAccountIssuer.new(organization: current_organization, email_domain: settings.email_domain)
        end

        # 招待フローと違い「本人がリンクを踏んだ」痕跡が残らないため、誰が・どのスペースに・
        # 何件発行したかを管理ログに残す（resource はアセンブリ）。
        def log_issue(results)
          tally = results.group_by(&:status).transform_values(&:count)

          Decidim::ActionLogger.log(
            "bulk_account_issue",
            current_user,
            current_assembly,
            nil,
            created: tally[:created].to_i,
            failed: tally[:failed].to_i
          )
        end

        # 平文パスワードとフリガナを含むCSV。Excel で開けるよう BOM を付ける。
        def results_csv(results)
          csv = CSV.generate do |out|
            out << Decidim::BulkSpaceAccountIssuer::RESULT_HEADERS
            results.each { |result| out << result.to_a }
          end

          "#{UTF8_BOM}#{csv}"
        end
      end
    end
  end
end
