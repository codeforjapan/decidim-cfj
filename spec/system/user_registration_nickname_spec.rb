# frozen_string_literal: true

require "rails_helper"

describe "User registration with nickname input", type: :system do
  let(:organization) { create(:organization) }

  before do
    switch_to_host(organization.host)
    visit decidim.new_user_registration_path
  end

  context "when registering with valid nickname" do
    it "allows user to register with custom nickname" do
      within "form.new_user" do
        fill_in "Name", with: "しながわ太郎"
        fill_in "Email", with: "test@example.com"
        fill_in "Nickname", with: "shinagawa_taro"
        fill_in "Password", with: "DfyvHn425mYAy2HL"
        check "I agree to the terms of service"

        click_button "Create an account"
      end

      expect(page).to have_content("confirmation email")
      
      user = Decidim::User.find_by(email: "test@example.com")
      expect(user).to be_present
      expect(user.nickname).to eq("shinagawa_taro")
      expect(user.name).to eq("しながわ太郎")
    end

    it "shows validation error for invalid nickname format" do
      within "form.new_user" do
        fill_in "Name", with: "テストユーザー"
        fill_in "Email", with: "test@example.com"
        fill_in "Nickname", with: "invalid@nickname"
        fill_in "Password", with: "DfyvHn425mYAy2HL"
        check "I agree to the terms of service"

        click_button "Create an account"
      end

      expect(page).to have_content("is invalid")
    end

    it "shows validation error for duplicate nickname" do
      create(:user, nickname: "existing_user", organization: organization)

      within "form.new_user" do
        fill_in "Name", with: "テストユーザー"
        fill_in "Email", with: "test@example.com"
        fill_in "Nickname", with: "existing_user"
        fill_in "Password", with: "DfyvHn425mYAy2HL"
        check "I agree to the terms of service"

        click_button "Create an account"
      end

      expect(page).to have_content("has already been taken")
    end

    it "shows help text for nickname field" do
      expect(page).to have_content("Enter any optional alphabetic characters")
    end
  end

  context "when nickname is empty" do
    it "falls back to generated nickname" do
      within "form.new_user" do
        fill_in "Name", with: "Test User"
        fill_in "Email", with: "test@example.com"
        # Leave nickname field empty
        fill_in "Password", with: "DfyvHn425mYAy2HL"
        check "I agree to the terms of service"

        click_button "Create an account"
      end

      expect(page).to have_content("confirmation email")
      
      user = Decidim::User.find_by(email: "test@example.com")
      expect(user).to be_present
      expect(user.nickname).to eq("Test_User")
    end
  end
end
