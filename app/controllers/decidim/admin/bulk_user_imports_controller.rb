# frozen_string_literal: true

require "csv"

module Decidim
  module Admin
    # 管理画面から CSV をアップロードして、招待メールを経由しない確定ユーザーを一括作成する。
    # 実際の作成処理は Decidim::BulkUserImporter が担う（詳細は docs/BULK_USER_IMPORT.md）。
    #
    # 同期処理のため、ファイルサイズと行数に上限を設けている。上限を超える規模が必要になったら
    # ActiveJob 化を検討すること。
    class BulkUserImportsController < Decidim::Admin::ApplicationController
      layout "decidim/admin/users"

      add_breadcrumb_item_from_menu :admin_user_menu

      helper_method :max_rows, :max_file_size

      # 独自リソースのため、コアの権限クラスは使わず専用のクラスだけをチェーンに登録する。
      # 理由は Decidim::BulkUserImportPermissions のコメントを参照。
      register_permissions(::Decidim::Admin::BulkUserImportsController,
                           ::Decidim::BulkUserImportPermissions)

      MAX_FILE_SIZE = 1.megabyte
      MAX_ROWS = 500
      RESULT_HEADERS = %w(email nickname name password status error).freeze
      UTF8_BOM = "\xEF\xBB\xBF"

      def new
        enforce_permission_to(:create, :bulk_user_import)
      end

      def create
        enforce_permission_to(:create, :bulk_user_import)

        file = uploaded_file
        return reject(:missing_file) unless file.respond_to?(:original_filename)
        return reject(:invalid_extension) unless csv_extension?(file)
        return reject(:file_too_large, size: max_file_size) if file.size > MAX_FILE_SIZE
        return reject(:missing_tos_version) if current_organization.tos_version.blank?

        table = parse_csv(file)
        return if performed?

        import(table)
      end

      private

      # 権限が無かったときの戻り先。
      #
      # コアの Decidim::Admin::ApplicationController は decidim_admin.root_path を返すが、
      # 管理ダッシュボードのルートは OrganizationDashboardConstraint の内側にあるため、そこへ
      # 入れない相手を /admin/ に送るとルートが一致せず、フォールバックした先の別エンジンの
      # root（`redirect("../edit")`）に拾われて /admin/../edit へ 301 され、Routing Error になる。
      # 管理画面に入れる相手だけダッシュボードへ戻し、それ以外は必ず解決できるパスへ戻す。
      def user_has_no_permission_path
        return decidim.new_user_session_path if current_user.blank?
        return decidim_admin.root_path if admin_dashboard_allowed?

        decidim.root_path
      end
      alias user_not_authorized_path user_has_no_permission_path

      # このコントローラの権限チェーンは :bulk_user_import 専用なので、ダッシュボードの可否は
      # コアの権限クラスに直接聞く（OrganizationDashboardConstraint と同じ判定）。
      def admin_dashboard_allowed?
        current_user.organization == current_organization &&
          allowed_to?(:read, :admin_dashboard, {}, [::Decidim::Admin::Permissions])
      end

      def max_rows
        MAX_ROWS
      end

      def max_file_size
        ActiveSupport::NumberHelper.number_to_human_size(MAX_FILE_SIZE)
      end

      def permission_class_chain
        ::Decidim.permissions_registry.chain_for(::Decidim::Admin::BulkUserImportsController)
      end

      # ファイル未添付でもエラー表示に留めるため、ParameterMissing を握って nil を返す。
      def uploaded_file
        params.require(:bulk_user_import).permit(:file)[:file]
      rescue ActionController::ParameterMissing
        nil
      end

      def csv_extension?(file)
        File.extname(file.original_filename.to_s).downcase == ".csv"
      end

      # 失敗時は new を描画し直す。500 にしないこと自体が要件なので 422 を返す。
      def reject(reason, **params)
        flash.now[:alert] = t("create.errors.#{reason}", scope: "decidim.admin.bulk_user_imports", **params)
        render :new, status: :unprocessable_entity
        nil
      end

      # 検証に通らなければ reject して nil を返す（呼び出し側は描画済みなので何もしない）。
      def parse_csv(file)
        content = read_utf8(file)
        return reject(:malformed_csv) if content.blank?

        table = CSV.parse(content, headers: true)
        return reject(:missing_email_header) unless table.headers.include?("email")
        return reject(:too_many_rows, max: max_rows) if table.size > max_rows
        return reject(:empty_csv) if table.empty?

        table
      rescue CSV::MalformedCSVError
        reject(:malformed_csv)
      end

      # Excel が書き出す BOM 付き UTF-8 をそのまま受け取れるようにする。不正なバイト列なら nil。
      def read_utf8(file)
        content = file.read.to_s.b.delete_prefix(UTF8_BOM.b).force_encoding(Encoding::UTF_8)
        return unless content.valid_encoding?

        content
      end

      def import(table)
        rows = table.map do |row|
          { email: row["email"], name: row["name"], nickname: row["nickname"], password: row["password"] }
        end

        results = Decidim::BulkUserImporter.new(organization: current_organization).import(rows)
        log_import(results)

        send_data results_csv(results),
                  type: "text/csv; charset=utf-8",
                  filename: "created_users_#{Time.current.strftime("%Y%m%d%H%M%S")}.csv",
                  disposition: "attachment"
      end

      # 招待フローと違い「本人がリンクを踏んだ」痕跡が残らないため、誰が・いつ・何件作成したかを管理ログに残す。
      #
      # Decidim::ActionLog は resource の presence を検証し、ActionLogger も resource.id を参照するため
      # resource に nil は渡せない。作成されたユーザーごとに残すと件数分のログで管理ログが埋まるので、
      # 実行単位で1件だけ、組織を resource として記録する（ログの organization は user.organization から引かれる）。
      def log_import(results)
        tally = results.group_by(&:status).transform_values(&:count)

        Decidim::ActionLogger.log(
          "bulk_user_import",
          current_user,
          current_organization,
          nil,
          created: tally[:created].to_i,
          skipped: tally[:skipped].to_i,
          failed: tally[:failed].to_i
        )
      end

      # 平文パスワードを含むCSV。Excel で開けるよう BOM を付ける。
      def results_csv(results)
        csv = CSV.generate do |out|
          out << RESULT_HEADERS
          results.each do |result|
            out << [result.email, result.nickname, result.name, result.password, result.status, result.error]
          end
        end

        "#{UTF8_BOM}#{csv}"
      end
    end
  end
end
