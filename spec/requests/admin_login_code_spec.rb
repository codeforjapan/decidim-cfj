# frozen_string_literal: true

require "rails_helper"

# Covers config/initializers/admin_login_code.rb.
RSpec.describe "Admin login code" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization) }
  let(:user) do
    create(:user, :admin, :confirmed, organization:,
                                      password_updated_at: Time.current, admin_terms_accepted_at: Time.current)
  end
  let(:enabled) { true }
  let(:admin_path) { "/admin/officializations" }
  let(:code) { "042195" }

  before do
    allow(Decidim::AdminLoginCode).to receive(:enabled?).and_return(enabled)
    allow(SecureRandom).to receive(:random_number).and_call_original
    allow(SecureRandom).to receive(:random_number).with(1_000_000).and_return(code.to_i)
    ActionMailer::Base.deliveries.clear
    host! organization.host
    sign_in user, scope: :user
  end

  it "redirects the admin panel to the code page" do
    get admin_path

    expect(response).to redirect_to("/admin_login_code/new")
  end

  it "answers non-HTML admin requests with 401" do
    get admin_path, headers: { "Accept" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
  end

  context "when the code page opens" do
    before do
      get admin_path
      get "/admin_login_code/new"
    end

    it "does not email a code until asked to" do
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("decidim.admin_login_codes.new.send"))
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  context "when the code is requested" do
    before do
      get admin_path
      post "/admin_login_code/deliver"
    end

    it "emails a code" do
      expect(response).to redirect_to("/admin_login_code/new")
      expect(ActionMailer::Base.deliveries.map(&:to)).to eq([[user.email]])
      expect(ActionMailer::Base.deliveries.last.html_part.body.decoded).to include(code)
    end

    it "does not email again within the interval" do
      post "/admin_login_code/deliver"

      expect(ActionMailer::Base.deliveries.size).to eq(1)
      expect(flash[:alert]).to eq(I18n.t("decidim.admin_login_codes.deliver.too_soon"))
    end
  end

  context "when the code is requested without visiting the admin panel" do
    before do
      get "/admin_login_code/new"
      post "/admin_login_code/deliver"
    end

    it "emails a code to a user who can enter the admin panel" do
      expect(ActionMailer::Base.deliveries.map(&:to)).to eq([[user.email]])
    end
  end

  context "when the email cannot be sent" do
    before do
      allow(Decidim::AdminLoginCodeMailer).to receive(:code).and_raise(Net::ReadTimeout)
      get admin_path
    end

    it "shows an error without keeping the unsent code" do
      post "/admin_login_code/deliver"

      expect(flash[:alert]).to eq(I18n.t("decidim.admin_login_codes.send_code.failed"))
      expect(Decidim::AdminLoginCode.find_by(user:).code_digest).to be_nil
    end

    it "does not retry the mail server within the interval" do
      post "/admin_login_code/deliver"
      post "/admin_login_code/deliver"

      expect(Decidim::AdminLoginCodeMailer).to have_received(:code).once
      expect(flash[:alert]).to eq(I18n.t("decidim.admin_login_codes.deliver.too_soon"))
    end
  end

  context "when the code page opens after the session has ended" do
    before do
      sign_out user
      get "/admin_login_code/new"
    end

    it "asks to sign in without returning to the code page afterwards" do
      expect(response).to redirect_to("/users/sign_in")
      expect(session["user_return_to"]).to be_nil
    end
  end

  context "when the code is entered" do
    before do
      get admin_path
      post "/admin_login_code/deliver"
      post "/admin_login_code", params: { admin_login_code: { code: } }
    end

    it "returns to the requested admin page" do
      expect(response).to redirect_to(admin_path)
    end

    it "opens the admin panel for the rest of the session" do
      get admin_path

      expect(response).to have_http_status(:ok)
    end

    it "requires and sends a new code after signing in again" do
      sign_out user
      sign_in user, scope: :user
      get admin_path

      expect(response).to redirect_to("/admin_login_code/new")
      post "/admin_login_code/deliver"
      expect(ActionMailer::Base.deliveries.size).to eq(2)
    end

    it "requires the code after signing in again when the password was changed elsewhere" do
      user.update!(password: "decidim123456789!Y", password_updated_at: Time.current)
      get admin_path
      sign_in user.reload, scope: :user
      get admin_path

      expect(response).to redirect_to("/admin_login_code/new")
    end
  end

  context "when a wrong code is entered" do
    before do
      get admin_path
      post "/admin_login_code/deliver"
      post "/admin_login_code", params: { admin_login_code: { code: "000000" } }
    end

    it "shows the form again" do
      expect(response).to have_http_status(:unprocessable_entity)
      get admin_path
      expect(response).to redirect_to("/admin_login_code/new")
    end
  end

  context "when the attempts are used up" do
    before do
      get admin_path
      post "/admin_login_code/deliver"
      Decidim::AdminLoginCode.find_by(user:).update!(failed_attempts: Decidim::AdminLoginCode::MAX_FAILED_ATTEMPTS)
      post "/admin_login_code", params: { admin_login_code: { code: } }
    end

    it "rejects the right code" do
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  context "when the last allowed wrong code is entered" do
    before do
      get admin_path
      post "/admin_login_code/deliver"
      Decidim::AdminLoginCode.find_by(user:).update!(total_failed_attempts: Decidim::AdminLoginCode::MAX_TOTAL_FAILED_ATTEMPTS - 1)
      post "/admin_login_code", params: { admin_login_code: { code: "000000" } }
    end

    it "shows the locked page" do
      follow_redirect!

      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include(I18n.t("decidim.admin_login_codes.locked.title"))
    end

    it "does not send a new code" do
      Decidim::AdminLoginCode.find_by(user:).update!(sent_at: 2.minutes.ago)
      post "/admin_login_code/deliver"

      expect(response).to have_http_status(:forbidden)
      expect(ActionMailer::Base.deliveries.size).to eq(1)
    end

    it "keeps the admin panel closed" do
      get admin_path
      follow_redirect!

      expect(response).to have_http_status(:forbidden)
    end
  end

  context "when a new code is requested right after the first one" do
    before do
      get admin_path
      post "/admin_login_code/deliver"
      post "/admin_login_code/deliver"
    end

    it "does not send it" do
      expect(ActionMailer::Base.deliveries.size).to eq(1)
      expect(flash[:alert]).to be_present
    end
  end

  context "when a new code is requested after the interval" do
    before do
      get admin_path
      post "/admin_login_code/deliver"
      Decidim::AdminLoginCode.find_by(user:).update!(sent_at: 2.minutes.ago)
      post "/admin_login_code/deliver"
    end

    it "sends it" do
      expect(ActionMailer::Base.deliveries.size).to eq(2)
    end
  end

  context "when a new code requested after the interval cannot be sent" do
    before do
      get admin_path
      post "/admin_login_code/deliver"
      Decidim::AdminLoginCode.find_by(user:).update!(sent_at: 2.minutes.ago)
      allow(Decidim::AdminLoginCodeMailer).to receive(:code).and_raise(Net::ReadTimeout)
      post "/admin_login_code/deliver"
      follow_redirect!
    end

    it "says that the code could not be sent" do
      expect(flash[:alert]).to eq(I18n.t("decidim.admin_login_codes.send_code.failed"))
    end
  end

  context "when the admin is impersonating a user" do
    let(:impersonated_user) { create(:user, :confirmed, organization:) }

    before do
      create(:impersonation_log, admin: user, user: impersonated_user, started_at: 1.minute.ago)
      get "/admin_login_code/new"
    end

    it "does not email a code to the impersonated user" do
      expect(response).to redirect_to("/")
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  context "when the user is a space admin" do
    let(:user) { create(:process_admin, :confirmed, participatory_process: create(:participatory_process, organization:)) }

    it "redirects the admin panel to the code page" do
      get "/admin/participatory_processes"

      expect(response).to redirect_to("/admin_login_code/new")
    end
  end

  context "when the user cannot enter the admin panel" do
    let(:user) { create(:user, :confirmed, organization:) }

    # A route outside OrganizationDashboardConstraint, so the request reaches the controller.
    before { get "/admin/bulk_user_import/new" }

    it "rejects the request without emailing a code" do
      expect(response).to redirect_to("/")
      expect(flash[:alert]).to be_present
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "does not let the code page email a code" do
      get "/admin_login_code/new"

      expect(response).to redirect_to("/")
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  context "when the feature is disabled" do
    let(:enabled) { false }

    it "opens the admin panel without a code" do
      get admin_path

      expect(response).to have_http_status(:ok)
    end
  end
end
