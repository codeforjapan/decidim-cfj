# frozen_string_literal: true

require "rails_helper"

describe "Admin manages officializations", type: :system do
  let(:model_name) { Decidim::User.model_name }
  let(:filterable_concern) { Decidim::Admin::Officializations::Filterable }

  let(:organization) { create(:organization) }

  let!(:admin) { create(:user, :admin, :confirmed, organization: organization) }
  let!(:user) { create(:user, :confirmed, organization: organization) }

  let!(:admin_authorization) do
    admin_metadata = { real_name: "admin", address: "admin address", gender: 1, birth_year: 2000, occupation: "administrator" }
    create(:authorization, user: admin, name: "user_extension", metadata: admin_metadata)
  end

  context "when signed in as user, not admin" do
    before do
      Capybara.raise_server_errors = false
      switch_to_host(organization.host)
      login_as user, scope: :user
    end

    it "cannot see admin dashboard page" do
      visit decidim_admin.root_path
      expect(page).to have_no_content("管理者ログ")
    end

    it "cannot see user_extension fragment" do
      visit main_app.user_extension_admin_officialization_path(user.id)
      expect(page).to have_no_content("参加者")
    end
  end

  context "when signed in as admin" do
    before do
      switch_to_host(organization.host)
      login_as admin, scope: :user
      visit decidim_admin.root_path
      click_link "参加者"
    end

    describe "listing officializations" do
      let!(:not_officialized) { create(:user, organization: organization) }

      before do
        within ".secondary-nav" do
          click_link "参加者"
        end
      end

      it "show users page" do
        expect(page).to have_content("ステータス")
        expect(page).to have_no_content("招待状が送信された日時")
      end

      it "has user_extension button" do
        expect(page).to have_css(".action-icon--show-user")

        anchor = first("a.action-icon--show-user")
        expect(anchor["data-toggle"]).to eq "show-user-modal"
        expect(anchor["title"]).to eq "ユーザー属性を表示"
      end
    end

    describe "retrieving the user extensional information" do
      let!(:users) { create_list(:user, 3, organization: organization) }

      before do
        users.each do |user|
          user_extension = {
            real_name: "#{user.nickname}_real",
            address: "Faker::Lorem.characters(number: 4)",
            gender: [0, 1, 2].shuffle,
            birth_year: (1990..2010).to_a.shuffle,
            occupation: "会社員"
          }
          create(:authorization, user: user, name: "user_extension", metadata: user_extension)
        end

        within ".secondary-nav" do
          click_link "参加者"
        end
      end

      it "shows the users emails to admin users and logs the action" do
        users.each do |user|
          within "tr[data-user-id=\"#{user.id}\"]" do
            click_link "ユーザー属性を表示"
          end

          within "#show-user-modal" do
            expect(page).to have_content("参加者の属性情報を表示")
            expect(page).not_to have_content("本名")

            click_button "表示"

            expect(page).to have_content("本名")
            expect(page).to have_content("#{user.nickname}_real")

            find("button[data-close]").click
          end
        end

        visit decidim_admin.root_path

        users.each do |user|
          expect(page).to have_content("#{admin.name} が #{user.name} にいくつかのアクションを実行しました")
        end
      end
    end
  end
end
