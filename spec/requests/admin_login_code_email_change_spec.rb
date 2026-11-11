# frozen_string_literal: true

require "rails_helper"
require "decidim/decidim_awesome/test/factories"
require "decidim/system/test/factories"

# Covers Decidim::NeedsAdminLoginCodeForEmailChange and the email changed notification.
RSpec.describe "Email change and the admin login code" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization) }
  let(:password) { "decidim123456789!X" }
  let(:user) do
    create(:user, :admin, :confirmed, organization:, password:,
                                      password_updated_at: Time.current, admin_terms_accepted_at: Time.current)
  end
  let(:new_email) { "new-address@example.org" }
  let(:account_params) do
    { user: { name: user.name, nickname: user.nickname, email: new_email, locale: "en", old_password: password } }
  end
  let(:code) { "042195" }

  before do
    allow(Decidim::AdminLoginCode).to receive(:enabled?).and_return(true)
    allow(SecureRandom).to receive(:random_number).and_call_original
    allow(SecureRandom).to receive(:random_number).with(1_000_000).and_return(code.to_i)
    host! organization.host
    sign_in user, scope: :user
  end

  context "when an admin changes the email without the code" do
    before { put "/account", params: account_params }

    it "asks for the code first" do
      expect(response).to redirect_to("/admin_login_code/new")
      expect(user.reload.unconfirmed_email).to be_nil
    end
  end

  context "when an admin has entered the code" do
    before do
      put "/account", params: account_params
      post "/admin_login_code/deliver"
      post "/admin_login_code", params: { admin_login_code: { code: } }
    end

    it "returns to the account page" do
      expect(response).to redirect_to("/account")
    end

    it "lets the email be changed" do
      put "/account", params: account_params

      expect(user.reload.unconfirmed_email).to eq(new_email)
    end
  end

  context "when an admin keeps the same email" do
    let(:new_email) { user.email.upcase }

    before { put "/account", params: account_params }

    it "does not ask for the code" do
      expect(response).not_to redirect_to("/admin_login_code/new")
    end
  end

  context "when a decidim_awesome scoped admin changes the email without the code" do
    let(:user) { create(:user, :confirmed, organization:, password:) }
    let!(:scoped_admins) { create(:awesome_config, organization:, var: "scoped_admins", value: { "team" => [user.id.to_s] }) }

    before { put "/account", params: account_params }

    it "asks for the code first" do
      expect(response).to redirect_to("/admin_login_code/new")
      expect(user.reload.unconfirmed_email).to be_nil
    end
  end

  context "when the user cannot enter the admin panel" do
    let(:user) { create(:user, :confirmed, organization:, password:) }

    before { put "/account", params: account_params }

    it "does not ask for the code" do
      expect(user.reload.unconfirmed_email).to eq(new_email)
    end
  end

  describe "the email changed notification" do
    let(:user) { create(:user, :confirmed, organization:, password:) }
    let!(:old_email) { user.email }

    before do
      ActionMailer::Base.deliveries.clear
      perform_enqueued_jobs { user.update!(email: new_email) }
    end

    it "is sent to the old address when the change is requested" do
      mail = ActionMailer::Base.deliveries.find { |m| m.to == [old_email] }

      expect(mail).to be_present
      body = mail.html_part&.body&.decoded || mail.body.decoded
      expect(body).to include(new_email)
      expect(body).to include(I18n.t("devise.mailer.email_changed.not_you"))
    end
  end

  describe "the email change of a system admin" do
    let(:system_admin) { create(:admin) }

    before { ActionMailer::Base.deliveries.clear }

    it "is not notified, as the notification cannot be rendered for a system admin" do
      expect { perform_enqueued_jobs { system_admin.update!(email: new_email) } }.not_to raise_error
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end
end
