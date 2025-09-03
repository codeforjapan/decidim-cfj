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
      fill_in "user_name", with: "しながわ太郎"
      fill_in "user_email", with: "test@example.com"
      fill_in "user_nickname", with: "shinagawa_taro"
      fill_in "user_password", with: "DfyvHn425mYAy2HL"
      check "user_tos_agreement"

      click_button "アカウント作成"

      expect(page).to have_content("確認メールを送信しました")

      user = Decidim::User.find_by(email: "test@example.com")
      expect(user).to be_present
      expect(user.nickname).to eq("shinagawa_taro")
      expect(user.name).to eq("しながわ太郎")
    end

    it "shows validation error for invalid nickname format" do
      fill_in "user_name", with: "テストユーザー"
      fill_in "user_email", with: "test@example.com"
      fill_in "user_nickname", with: "invalid@nickname"
      fill_in "user_password", with: "DfyvHn425mYAy2HL"
      check "user_tos_agreement"

      click_button "アカウント作成"

      expect(page).to have_content("Nicknameは不正な値です")
    end

    it "shows validation error for duplicate nickname" do
      create(:user, nickname: "existing_user", organization:)

      fill_in "user_name", with: "テストユーザー"
      fill_in "user_email", with: "test@example.com"
      fill_in "user_nickname", with: "existing_user"
      fill_in "user_password", with: "DfyvHn425mYAy2HL"
      check "user_tos_agreement"

      click_button "アカウント作成"

      expect(page).to have_content("Nicknameはすでに存在します")
    end

    it "shows help text for nickname field" do
      expect(page).to have_content("アルファベット小文字、数字、'-' および '_' を使用できます。")
    end
  end

  context "when nickname is empty" do
    it "falls back to generated nickname" do
      fill_in "user_name", with: "Test User"
      fill_in "user_email", with: "test@example.com"
      # Leave nickname field empty
      fill_in "user_password", with: "DfyvHn425mYAy2HL"
      check "user_tos_agreement"

      click_button "アカウント作成"

      expect(page).to have_content("確認メールを送信しました")

      user = Decidim::User.find_by(email: "test@example.com")
      expect(user).to be_present
      expect(user.nickname).to eq("Test_User")
    end
  end
end
