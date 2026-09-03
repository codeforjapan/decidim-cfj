# frozen_string_literal: true

require "rails_helper"

# アセンブリ管理画面の一括アカウント発行（Decidim::Assemblies::Admin::BulkAccountIssuesController)
RSpec.describe "Decidim::Assemblies::Admin BulkAccountIssuesController" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization, tos_version: Time.current) }
  let!(:assembly) do
    create(:assembly, organization:, slug: "a-high", private_space: true, is_transparent: false)
  end
  let!(:settings) do
    Decidim::BulkUserImportSetting.create!(organization:, email_domain: "chiba-mirai.test", enabled: true)
  end
  let(:admin_user) { create(:user, :admin, :confirmed, organization:) }
  let(:new_path) { "/admin/assemblies/#{assembly.slug}/bulk_account_issue/new" }
  let(:create_path) { "/admin/assemblies/#{assembly.slug}/bulk_account_issue" }
  let(:params) { { bulk_account_issue: { participant_count: 2, admin_count: 1 } } }

  before { host! organization.host }

  def issued_users
    Decidim::User.where(organization:).where("nickname LIKE ?", "a-high-%")
  end

  # サイドメニュー「アカウント一括発行」の表示条件（MVP）:
  # /system でこの組織の発行が有効 かつ スペースが非公開、の両方を満たすときだけ表示する。
  # メニュー（admin_assembly_menu）を描画する任意の管理ページで確認できる（ここでは添付ファイル一覧）。
  describe "menu visibility" do
    let(:menu_page_path) { "/admin/assemblies/#{assembly.slug}/attachments" }

    before { sign_in admin_user }

    it "shows the menu item when the organization is enabled and the space is private" do
      get menu_page_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(new_path)
    end

    context "when the assembly is not a private space" do
      before { assembly.update!(private_space: false) }

      it "hides the menu item" do
        get menu_page_path

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include(new_path)
      end
    end

    context "when issuing is disabled for the organization" do
      before { settings.update!(enabled: false) }

      it "hides the menu item" do
        get menu_page_path

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include(new_path)
      end
    end

    # MenuItem#visible? は if: が nil のとき「条件指定なし＝表示」と解釈するため、
    # 設定レコードが無い組織で find_by → nil が漏れると全表示になる（過去の不具合の回帰テスト）。
    context "when the organization has no settings record" do
      before { settings.destroy! }

      it "hides the menu item" do
        get menu_page_path

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include(new_path)
      end
    end

    # マルチテナント: 他組織で有効になっていても、この組織には漏れないこと（逆方向も確認する）。
    context "when only another organization has issuing enabled" do
      let(:other_organization) { create(:organization, tos_version: Time.current) }

      before do
        settings.destroy!
        Decidim::BulkUserImportSetting.create!(organization: other_organization,
                                               email_domain: "other.test", enabled: true)
      end

      it "hides the menu item in this organization" do
        get menu_page_path

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include(new_path)
      end

      it "still shows the menu item in the enabled organization" do
        other_assembly = create(:assembly, organization: other_organization, slug: "b-high",
                                           private_space: true, is_transparent: false)
        other_admin = create(:user, :admin, :confirmed, organization: other_organization)

        host! other_organization.host
        sign_in other_admin
        get "/admin/assemblies/#{other_assembly.slug}/attachments"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("/admin/assemblies/b-high/bulk_account_issue/new")
      end
    end
  end

  describe "GET new" do
    context "without a signed in user" do
      it "redirects to the sign in page" do
        get new_path

        expect(response).to redirect_to("/users/sign_in")
      end
    end

    context "with a regular user" do
      before { sign_in create(:user, :confirmed, organization:) }

      it "redirects to a routable path instead of rendering the form" do
        get new_path

        expect(response).to have_http_status(:redirect)
        expect { get(response.location) }.not_to raise_error
      end
    end

    context "with an organization admin" do
      before { sign_in admin_user }

      it "renders the form with the next ids and the domain" do
        get new_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("a-high-001")
        expect(response.body).to include("a-high-a001")
        expect(response.body).to include("chiba-mirai.test")
      end

      context "when issuing is disabled for the organization" do
        before { settings.update!(enabled: false) }

        it "redirects to the assemblies list with an explanation" do
          get new_path

          expect(response).to redirect_to("/admin/assemblies")
          expect(flash[:alert]).to be_present
        end
      end

      context "when the assembly is not a private space" do
        before { assembly.update!(private_space: false) }

        it "redirects to the assemblies list with an explanation" do
          get new_path

          expect(response).to redirect_to("/admin/assemblies")
          expect(flash[:alert]).to be_present
        end
      end

      # 他組織の設定が current_organization の判定に漏れて有効化されないこと。
      context "when issuing is enabled only for another organization" do
        before do
          settings.destroy!
          Decidim::BulkUserImportSetting.create!(organization: create(:organization, tos_version: Time.current),
                                                 email_domain: "other.test", enabled: true)
        end

        it "redirects to the assemblies list with an explanation" do
          get new_path

          expect(response).to redirect_to("/admin/assemblies")
          expect(flash[:alert]).to be_present
        end
      end
    end
  end

  describe "POST create" do
    context "with an organization admin" do
      before { sign_in admin_user }

      it "issues the accounts and returns the credentials as a CSV" do
        expect { post(create_path, params:) }.to change(Decidim::User, :count).by(3)

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("text/csv")
        expect(response.body).to include("a-high-001")
        expect(response.body).to include("a-high-002")
        expect(response.body).to include("a-high-a001")
        expect(response.body).to include("・") # フリガナ列
        expect(response.headers["Cache-Control"]).to include("no-store")
      end

      it "links the accounts to the space" do
        post(create_path, params:)

        users = issued_users
        expect(Decidim::ParticipatorySpacePrivateUser.where(user: users, privatable_to: assembly).count).to eq(3)
        expect(Decidim::AssemblyUserRole.where(user: users, assembly:, role: "admin").count).to eq(1)
        users.each { |user| expect(assembly.can_participate?(user)).to be(true) }
      end

      it "records the issue in the admin log and renders it" do
        post(create_path, params:)

        log = Decidim::ActionLog.find_by(action: "bulk_account_issue")
        expect(log).to be_present
        expect(log.resource).to eq(assembly)
        expect(log.extra["created"]).to eq(3)

        get "/admin/logs"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("bulk-issued accounts")
      end

      it "does not enqueue any email" do
        expect { post(create_path, params:) }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end

      it "rejects zero accounts" do
        post create_path, params: { bulk_account_issue: { participant_count: 0, admin_count: 0 } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(issued_users.count).to eq(0)
      end

      it "rejects negative counts" do
        post create_path, params: { bulk_account_issue: { participant_count: -1, admin_count: 2 } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(issued_users.count).to eq(0)
      end

      it "rejects more than the per-request cap" do
        post create_path, params: { bulk_account_issue: { participant_count: 60, admin_count: 41 } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(issued_users.count).to eq(0)
      end

      context "when the slug is longer than the id budget allows" do
        let!(:assembly) do
          create(:assembly, organization:, slug: "a" * 16, private_space: true, is_transparent: false)
        end
        let(:create_path) { "/admin/assemblies/#{assembly.slug}/bulk_account_issue" }

        it "rejects the request" do
          post(create_path, params:)

          expect(response).to have_http_status(:unprocessable_entity)
          expect(Decidim::User.where(organization:).where("nickname LIKE ?", "aaaa%").count).to eq(0)
        end
      end

      context "when the organization has no tos_version" do
        before do
          # 組織ファクトリは after(:create) で必ず tos_version を設定するため直接消す
          Decidim::Organization.where(id: organization.id).update_all(tos_version: nil) # rubocop:disable Rails/SkipsModelValidations
        end

        it "rejects the request instead of creating users that count as not having accepted the TOS" do
          post(create_path, params:)

          expect(response).to have_http_status(:unprocessable_entity)
          expect(issued_users.count).to eq(0)
        end
      end
    end

    context "when issuing is disabled for the organization" do
      before do
        settings.update!(enabled: false)
        sign_in admin_user
      end

      it "does not create any user" do
        post(create_path, params:)

        expect(response).to have_http_status(:redirect)
        expect(issued_users.count).to eq(0)
      end
    end

    # 他組織で有効でも、この組織では発行できないこと（設定の組織スコープの検証）。
    context "when issuing is enabled only for another organization" do
      before do
        settings.destroy!
        Decidim::BulkUserImportSetting.create!(organization: create(:organization, tos_version: Time.current),
                                               email_domain: "other.test", enabled: true)
        sign_in admin_user
      end

      it "does not create any user" do
        post(create_path, params:)

        expect(response).to have_http_status(:redirect)
        expect(issued_users.count).to eq(0)
      end
    end

    context "with a space admin who is not an organization admin" do
      let(:space_admin) { create(:user, :confirmed, organization:) }

      before do
        Decidim::AssemblyUserRole.create!(user: space_admin, assembly:, role: "admin")
        sign_in space_admin
      end

      it "cannot issue accounts" do
        post(create_path, params:)

        expect(response).to have_http_status(:redirect)
        expect(issued_users.count).to eq(0)
      end
    end

    context "with a user manager" do
      before { sign_in create(:user, :user_manager, :confirmed, organization:) }

      it "cannot issue accounts" do
        post(create_path, params:)

        expect(response).to have_http_status(:redirect)
        expect(issued_users.count).to eq(0)
      end
    end

    context "with an admin of another organization" do
      let(:other_organization) { create(:organization, tos_version: Time.current) }
      let(:other_admin) { create(:user, :admin, :confirmed, organization: other_organization) }

      before { sign_in other_admin }

      it "cannot issue accounts in this organization" do
        post(create_path, params:)

        expect(response).to have_http_status(:redirect)
        expect(issued_users.count).to eq(0)
      end
    end

    context "without a signed in user" do
      it "does not create any user" do
        post(create_path, params:)

        expect(response).to have_http_status(:redirect)
        expect(issued_users.count).to eq(0)
      end
    end
  end
end
