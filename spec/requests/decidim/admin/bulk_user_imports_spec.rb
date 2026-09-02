# frozen_string_literal: true

require "rails_helper"

# Verifies the admin UI for `Decidim::BulkUserImporter`
# (`Decidim::Admin::BulkUserImportsController`).
RSpec.describe "Decidim::Admin BulkUserImportsController" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization, tos_version: Time.current) }
  let(:admin_user) { create(:user, :admin, :confirmed, organization:) }
  let(:regular_user) { create(:user, :confirmed, organization:) }
  let(:email) { "taro.yamada@example.com" }
  let(:csv_body) { "email,name\n#{email},山田 太郎\n" }
  let(:params) { { bulk_user_import: { file: upload(csv_body) } } }

  before { host! organization.host }

  def upload(content, filename: "users.csv", type: "text/csv")
    file = Tempfile.new(["bulk_user_import", File.extname(filename)])
    file.binmode
    file.write(content)
    file.rewind

    Rack::Test::UploadedFile.new(file.path, type, original_filename: filename)
  end

  describe "GET new" do
    context "without a signed in user" do
      it "redirects to the sign in page instead of rendering the form" do
        get decidim_admin.new_bulk_user_import_path

        expect(response).to redirect_to(decidim.new_user_session_path)
      end

      # リダイレクト先が解決できないと Routing Error になるため、追跡して 200 まで確認する
      it "redirects to a routable path" do
        get decidim_admin.new_bulk_user_import_path

        expect { follow_redirect! }.not_to raise_error
        expect(response).to have_http_status(:ok)
      end
    end

    context "with a regular user" do
      before { sign_in regular_user, scope: :user }

      it "redirects to the public root instead of rendering the form" do
        get decidim_admin.new_bulk_user_import_path

        expect(response).to redirect_to(decidim.root_path)
        expect(flash[:alert]).to eq(I18n.t("actions.unauthorized", scope: "decidim.core"))
      end

      # 管理ダッシュボードは OrganizationDashboardConstraint の内側にあり、一般ユーザーを
      # /admin/ に送ると Routing Error になる。リダイレクト先が解決できることを固定する。
      it "redirects to a routable path" do
        get decidim_admin.new_bulk_user_import_path

        expect { follow_redirect! }.not_to raise_error
        expect(response).to have_http_status(:ok)
      end
    end

    context "with an organization admin" do
      before { sign_in admin_user, scope: :user }

      it "renders the form" do
        get decidim_admin.new_bulk_user_import_path

        expect(response).to have_http_status(:ok)
        # multipart でないとファイルがサーバに届かないため、enctype を固定しておく
        expect(response.body).to include(%(enctype="multipart/form-data"))
        expect(response.body).to include(%(name="bulk_user_import[file]"))
      end
    end
  end

  describe "POST create" do
    context "without a signed in user" do
      it "does not create any user" do
        expect { post(decidim_admin.bulk_user_import_path, params:) }.not_to change(Decidim::User, :count)

        expect(response).not_to have_http_status(:ok)
      end
    end

    context "with a regular user" do
      before { sign_in regular_user, scope: :user }

      it "does not create any user" do
        expect { post(decidim_admin.bulk_user_import_path, params:) }.not_to change(Decidim::User, :count)

        expect(response).not_to have_http_status(:ok)
      end
    end

    context "with an organization admin" do
      before { sign_in admin_user, scope: :user }

      it "creates the user and returns the credentials as a CSV" do
        post(decidim_admin.bulk_user_import_path, params:)

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/csv")
        expect(response.headers["Content-Disposition"]).to match(/created_users_\d{14}\.csv/)
        expect(response.body).to include("email,nickname,name,password,status,error")
        expect(response.body).to include(email)
        expect(response.body).to include("created")
      end

      it "creates the user in the current organization" do
        expect { post(decidim_admin.bulk_user_import_path, params:) }.to change(Decidim::User, :count).by(1)

        user = Decidim::User.find_by(email:)
        expect(user.organization).to eq(organization)
        expect(user).to be_confirmed
      end

      it "does not send any email" do
        expect { post(decidim_admin.bulk_user_import_path, params:) }.not_to(change { ActionMailer::Base.deliveries.count })
      end

      it "records the import in the admin log" do
        expect { post(decidim_admin.bulk_user_import_path, params:) }.to change(Decidim::ActionLog, :count).by(1)

        log = Decidim::ActionLog.last
        expect(log.action).to eq("bulk_user_import")
        expect(log.user).to eq(admin_user)
        expect(log.organization).to eq(organization)
        expect(log.extra["created"]).to eq(1)
      end

      it "renders the import on the admin log page" do
        post(decidim_admin.bulk_user_import_path, params:)

        get decidim_admin.logs_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("imported users in bulk (1 created / 0 skipped / 0 failed)")
      end

      # 画面とドキュメントで「Excel の BOM 付き UTF-8 をそのまま読める」と説明しているため固定する
      context "when the CSV has a UTF-8 BOM" do
        let(:csv_body) { "\uFEFFemail,name\n#{email},山田 太郎\n" }

        it "strips the BOM and imports the row" do
          expect { post(decidim_admin.bulk_user_import_path, params:) }.to change(Decidim::User, :count).by(1)

          expect(response).to have_http_status(:ok)
          expect(Decidim::User.find_by(email:)).to be_present
        end
      end

      context "when the file is larger than the size limit" do
        let(:csv_body) { "email\n#{"a" * Decidim::Admin::BulkUserImportsController::MAX_FILE_SIZE}@example.com\n" }

        it "rejects the file" do
          expect { post(decidim_admin.bulk_user_import_path, params:) }.not_to change(Decidim::User, :count)

          expect(response).to have_http_status(:unprocessable_entity)
          expect(flash[:alert]).to eq(
            I18n.t(
              "decidim.admin.bulk_user_imports.create.errors.file_too_large",
              size: ActiveSupport::NumberHelper.number_to_human_size(
                Decidim::Admin::BulkUserImportsController::MAX_FILE_SIZE
              )
            )
          )
        end
      end

      context "when no file is attached" do
        it "renders an error instead of failing" do
          post decidim_admin.bulk_user_import_path

          expect(response).to have_http_status(:unprocessable_entity)
          expect(flash[:alert]).to eq(I18n.t("decidim.admin.bulk_user_imports.create.errors.missing_file"))
        end
      end

      context "when the extension is not .csv" do
        let(:params) { { bulk_user_import: { file: upload(csv_body, filename: "users.txt", type: "text/plain") } } }

        it "rejects the file" do
          expect { post(decidim_admin.bulk_user_import_path, params:) }.not_to change(Decidim::User, :count)

          expect(response).to have_http_status(:unprocessable_entity)
          expect(flash[:alert]).to eq(I18n.t("decidim.admin.bulk_user_imports.create.errors.invalid_extension"))
        end
      end

      context "when the CSV is malformed" do
        let(:csv_body) { %(email,name\n"unterminated,山田 太郎\n) }

        it "renders an error instead of failing" do
          expect { post(decidim_admin.bulk_user_import_path, params:) }.not_to change(Decidim::User, :count)

          expect(response).to have_http_status(:unprocessable_entity)
          expect(flash[:alert]).to eq(I18n.t("decidim.admin.bulk_user_imports.create.errors.malformed_csv"))
        end
      end

      context "when the CSV has no email header" do
        let(:csv_body) { "name\n山田 太郎\n" }

        it "rejects the file" do
          expect { post(decidim_admin.bulk_user_import_path, params:) }.not_to change(Decidim::User, :count)

          expect(response).to have_http_status(:unprocessable_entity)
          expect(flash[:alert]).to eq(I18n.t("decidim.admin.bulk_user_imports.create.errors.missing_email_header"))
        end
      end

      # 上限そのものを守る。spec の他の箇所は MAX_ROWS を動的に参照するため、値を引き上げても
      # 気づけない。管理画面はどちらも CloudFront の OriginReadTimeout 30秒の内側で完了する必要が
      # あり、CSV 取り込みは 1 行あたりの処理がアセンブリ側の発行より重い（パスワード生成の
      # リトライと任意項目の検証が乗る）ため、発行側の上限を超えてはならない。
      it "does not allow more rows than the assembly issuing cap" do
        expect(described_cap).to be <= Decidim::Assemblies::Admin::BulkAccountIssuesController::MAX_ACCOUNTS_PER_REQUEST
      end

      context "when the row limit is exceeded" do
        let(:max_rows) { Decidim::Admin::BulkUserImportsController::MAX_ROWS }
        let(:csv_body) do
          rows = Array.new(max_rows + 1) { |index| "user#{index}@example.com" }
          "email\n#{rows.join("\n")}\n"
        end

        it "rejects the file" do
          expect { post(decidim_admin.bulk_user_import_path, params:) }.not_to change(Decidim::User, :count)

          expect(response).to have_http_status(:unprocessable_entity)
          expect(flash[:alert]).to eq(
            I18n.t("decidim.admin.bulk_user_imports.create.errors.too_many_rows", max: max_rows)
          )
        end
      end
    end

    context "with a user manager" do
      let(:user_manager) { create(:user, :user_manager, :confirmed, organization:) }

      before { sign_in user_manager, scope: :user }

      # 管理画面には入れるが admin ではないので拒否する。戻り先は入れる範囲で近い場所にする
      it "cannot import and is sent back to the admin dashboard" do
        expect { post(decidim_admin.bulk_user_import_path, params:) }.not_to change(Decidim::User, :count)

        expect(response).to redirect_to(decidim_admin.root_path)
        expect { follow_redirect! }.not_to raise_error
        expect(response).to have_http_status(:ok)
      end
    end

    context "with an admin of another organization" do
      let(:other_organization) { create(:organization, tos_version: Time.current) }
      let(:other_admin) { create(:user, :admin, :confirmed, organization: other_organization) }

      before { sign_in other_admin, scope: :user }

      it "cannot create users in this organization" do
        expect { post(decidim_admin.bulk_user_import_path, params:) }.not_to change(Decidim::User, :count)

        expect(response).not_to have_http_status(:ok)
        expect(Decidim::User.find_by(email:)).to be_nil
      end

      # 他組織のadminは /admin/ にも入れないため、管理画面ではなく公開側に戻す
      it "redirects to a routable path" do
        post(decidim_admin.bulk_user_import_path, params:)

        expect(response).to redirect_to(decidim.root_path)
        expect { follow_redirect! }.not_to raise_error
        expect(response).to have_http_status(:ok)
      end
    end
  end

  def described_cap = Decidim::Admin::BulkUserImportsController::MAX_ROWS
end
