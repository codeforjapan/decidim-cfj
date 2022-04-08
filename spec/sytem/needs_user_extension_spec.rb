# frozen_string_literal: true

require "rails_helper"

describe "Need user extension", type: :system do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :confirmed, organization: organization) }

  context "when user_extension is enable" do
    let(:organization) { create(:organization, available_authorizations: ["user_extension_authorization_handler"]) }

    context "when signed in as user" do
      before do
        Capybara.raise_server_errors = false
        switch_to_host(organization.host)
        login_as user, scope: :user
      end

      context "without user extension" do
        it "redirect to account page" do
          visit decidim.notifications_path
          expect(page).to have_current_path(decidim.account_path, ignore_query: true)
        end

        it "not redirect in root page" do
          visit decidim.root_path
          expect(page).to have_current_path(decidim.root_path)
        end
      end

      context "with user extension" do
        before do
          user_extension = {
            real_name: "#{user.nickname}_real",
            address: "Faker::Lorem.characters(number: 4)",
            gender: [0, 1, 2].shuffle,
            birth_year: (1990..2010).to_a.shuffle,
            occupation: "会社員"
          }
          create(:authorization, user: user, name: "user_extension", metadata: user_extension)
        end

        it "not redirect in notifications page" do
          visit decidim.notifications_path
          expect(page).to have_current_path(decidim.notifications_path)
        end

        it "not redirect in root page" do
          visit decidim.root_path
          expect(page).to have_current_path(decidim.root_path)
        end
      end
    end
  end

  context "when user_extension is disable" do
    context "when signed in as user" do
      before do
        Capybara.raise_server_errors = false
        switch_to_host(organization.host)
        login_as user, scope: :user
      end

      context "without user extension" do
        it "not redirect in notifications page" do
          visit decidim.notifications_path
          expect(page).to have_current_path(decidim.notifications_path)
        end

        it "not redirect in root page" do
          visit decidim.root_path
          expect(page).to have_current_path(decidim.root_path)
        end
      end

      context "with user extension" do
        before do
          user_extension = {
            real_name: "#{user.nickname}_real",
            address: "Faker::Lorem.characters(number: 4)",
            gender: [0, 1, 2].shuffle,
            birth_year: (1990..2010).to_a.shuffle,
            occupation: "会社員"
          }
          create(:authorization, user: user, name: "user_extension", metadata: user_extension)
        end

        it "not redirect in notifications page" do
          visit decidim.notifications_path
          expect(page).to have_current_path(decidim.notifications_path)
        end

        it "not redirect in root page" do
          visit decidim.root_path
          expect(page).to have_current_path(decidim.root_path)
        end
      end
    end
  end
end
