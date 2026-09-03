# frozen_string_literal: true

require "csv"

module Decidim
  module Assemblies
    module Admin
      # 各アセンブリの管理画面から、匿名IDの確定アカウントを一括発行する。
      # スペースはURL（:assembly_slug）から確定するため、入力は「参加者数・管理者数」だけ。
      # 実際の発行は Decidim::BulkSpaceAccountIssuer が担う（詳細は docs/BULK_SPACE_ACCOUNTS.md）。
      #
      # 同期処理のため1回の発行数に上限を設けている。超える場合は複数回に分けるか rake を使う。
      class BulkAccountIssuesController < Decidim::Assemblies::Admin::ApplicationController
        include Concerns::AssemblyAdmin

        # 独自リソースのため、コアの権限クラスは使わず専用クラスだけをチェーンに登録する。
        # 理由は Decidim::BulkAccountIssuePermissions のコメントを参照。
        register_permissions(::Decidim::Assemblies::Admin::BulkAccountIssuesController,
                             ::Decidim::BulkAccountIssuePermissions)

        # 本番の CloudFront は既定30秒でオリジン応答を打ち切る。実測 0.19秒/件（bcrypt支配）から
        # 約150件が限界のため、安全マージンを見て100件とする。
        MAX_ACCOUNTS_PER_REQUEST = 100
        RESULT_HEADERS = %w(space_slug role account_id email password furigana status error).freeze
        UTF8_BOM = "\xEF\xBB\xBF"

        helper_method :settings, :max_accounts, :slug_too_long?, :next_account_ids

        def new
          enforce_permission_to(:create, :bulk_account_issue)
          redirect_unless_available
        end

        def create
          enforce_permission_to(:create, :bulk_account_issue)
          return if redirect_unless_available

          participant_count = requested_count(:participant_count)
          admin_count = requested_count(:admin_count)
          total = participant_count + admin_count

          return reject(:negative_counts) if participant_count.negative? || admin_count.negative?
          return reject(:no_accounts) if total.zero?
          return reject(:too_many_accounts, max: max_accounts) if total > MAX_ACCOUNTS_PER_REQUEST
          return reject(:slug_too_long, max: Decidim::BulkSpaceAccountIssuer::MAX_SLUG_LENGTH) if slug_too_long?
          return reject(:missing_tos_version) if current_organization.tos_version.blank?

          results = issuer.issue(build_instructions(participant_count, admin_count))
          log_issue(results)

          send_data results_csv(results),
                    type: "text/csv; charset=utf-8",
                    filename: "issued_accounts_#{Time.current.strftime("%Y%m%d%H%M%S")}.csv",
                    disposition: "attachment"
        rescue ArgumentError => e
          # BulkSpaceAccountIssuer#validate! の検証エラー（原則ここには来ない: 上のガードで先に弾く）
          flash.now[:alert] = e.message
          render :new, status: :unprocessable_entity
        end

        private

        # このコントローラのチェーンは :bulk_account_issue 専用（AssemblyAdmin concern の
        # chain_for(AssemblyAdmin) を上書きする。include より後に定義しているのでこちらが勝つ）。
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
          MAX_ACCOUNTS_PER_REQUEST
        end

        def slug_too_long?
          current_assembly.slug.downcase.length > Decidim::BulkSpaceAccountIssuer::MAX_SLUG_LENGTH
        end

        # 次に採番されるID（形式ごと）。dry_run の発行でIDだけ計算する。
        def next_account_ids
          @next_account_ids ||= begin
            dry = Decidim::BulkSpaceAccountIssuer.new(organization: current_organization,
                                                      email_domain: settings.email_domain, dry_run: true)
            %w(participant admin).index_with do |role|
              dry.issue([{ space_type: "assemblies", space_slug: current_assembly.slug, role:, count: 1 }])
                 .first.account_id
            end
          end
        end

        def requested_count(key)
          params.dig(:bulk_account_issue, key).to_s.strip.to_i
        end

        def build_instructions(participant_count, admin_count)
          [
            { space_type: "assemblies", space_slug: current_assembly.slug, role: "participant", count: participant_count },
            { space_type: "assemblies", space_slug: current_assembly.slug, role: "admin", count: admin_count }
          ].select { |instruction| instruction[:count].positive? }
        end

        def issuer
          Decidim::BulkSpaceAccountIssuer.new(organization: current_organization, email_domain: settings.email_domain)
        end

        # 失敗時は new を描画し直す。500 にしないこと自体が要件なので 422 を返す。
        def reject(reason, **params)
          flash.now[:alert] = t("create.errors.#{reason}", scope: "decidim.assemblies.admin.bulk_account_issues", **params)
          render :new, status: :unprocessable_entity
          nil
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
            out << RESULT_HEADERS
            results.each do |result|
              out << [result.space_slug, result.role, result.account_id, result.email,
                      result.password, result.furigana, result.status, result.error]
            end
          end

          "#{UTF8_BOM}#{csv}"
        end
      end
    end
  end
end
