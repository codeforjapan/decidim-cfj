# frozen_string_literal: true

require "rails_helper"

describe "User registration with nickname input" do
  let(:organization) { create(:organization) }

  before do
    switch_to_host(organization.host)
    visit decidim.new_user_registration_path
  end

  context "when registering with valid nickname" do
    it "allows user to register with custom nickname" do
      within "form.new_user" do
        fill_in "表示名", with: "しながわ太郎"
        fill_in "あなたのメールアドレス", with: "test@example.com"
        fill_in "アカウントID", with: "shinagawa_taro"
        fill_in "パスワード", with: "DfyvHn425mYAy2HL"
        check "ユーザ登録することで、 利用規約 に同意したことになります。"

        click_button "アカウントを作成"
      end
      click_button "確認して続ける"

      expect(page).to have_content("確認リンクが記載されたメッセージがあなたのメールアドレスに送信されました")

      user = Decidim::User.find_by(email: "test@example.com")
      expect(user).to be_present
      expect(user.nickname).to eq("shinagawa_taro")
      expect(user.name).to eq("しながわ太郎")
    end

    it "shows validation error for invalid nickname format" do
      within "form.new_user" do
        fill_in "表示名", with: "テストユーザー"
        fill_in "あなたのメールアドレス", with: "test@example.com"
        fill_in "アカウントID", with: "invalid@nickname"
        fill_in "パスワード", with: "DfyvHn425mYAy2HL"
        check "ユーザ登録することで、 利用規約 に同意したことになります。"

        click_button "アカウントを作成"
      end
      click_button "確認して続ける"

      expect(page).to have_content("は不正な値です")
    end

    it "shows validation error for duplicate nickname" do
      create(:user, nickname: "existing_user", organization:)

      within "form.new_user" do
        fill_in "表示名", with: "テストユーザー"
        fill_in "あなたのメールアドレス", with: "test@example.com"
        fill_in "アカウントID", with: "existing_user"
        fill_in "パスワード", with: "DfyvHn425mYAy2HL"
        check "ユーザ登録することで、 利用規約 に同意したことになります。"

        click_button "アカウントを作成"
      end
      click_button "確認して続ける"

      expect(page).to have_content("はすでに存在します")
    end

    it "shows help text for nickname field" do
      expect(page).to have_content("アルファベット小文字、数字、'-' および '_' を使用できます。")
    end
  end
end
