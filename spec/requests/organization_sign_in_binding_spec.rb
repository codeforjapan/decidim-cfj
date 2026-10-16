# frozen_string_literal: true

require "rails_helper"

# Covers the sign_in override in
# config/initializers/organization_session_binding.rb: sign-in paths that find
# the user by token alone must not sign them in on another organization's host.
RSpec.describe "Sign-in bound to the organization" do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:password) { "decidim123456789" }
  let(:new_password) { "a-brand-new-decidim-password" }
  # 0.32 で全 URL がロケール接頭辞つきになったため、パスはルートヘルパーから引く。
  let(:decidim_routes) { Decidim::Core::Engine.routes.url_helpers }
  let(:session_key) { request.session["warden.user.user.key"] }

  before { host! target_host }

  describe "email confirmation" do
    let(:user) { create(:user, organization:) }

    before { get decidim_routes.user_confirmation_path, params: { confirmation_token: user.confirmation_token } }

    context "when opened on the user's organization" do
      let(:target_host) { organization.host }

      it "confirms and signs in the user" do
        expect(user.reload).to be_confirmed
        expect(session_key).to be_present
        expect(user.sign_in_count).to eq(1)
      end
    end

    context "when opened on another organization" do
      let(:target_host) { other_organization.host }

      it "confirms the user without signing them in" do
        expect(user.reload).to be_confirmed
        expect(response).to redirect_to(decidim_routes.new_user_session_path)
        expect(session_key).to be_nil
        expect(user.sign_in_count).to eq(0)
      end
    end
  end

  describe "password reset" do
    let(:user) { create(:user, :confirmed, organization:, password:) }
    let(:token) { user.send_reset_password_instructions }

    before do
      put decidim_routes.user_password_path, params: { user: { reset_password_token: token, password: new_password, password_confirmation: new_password } }
    end

    context "when submitted on the user's organization" do
      let(:target_host) { organization.host }

      it "changes the password and signs in the user" do
        expect(user.reload.valid_password?(new_password)).to be(true)
        expect(session_key).to be_present
      end
    end

    context "when submitted on another organization" do
      let(:target_host) { other_organization.host }

      it "changes the password without signing in the user" do
        expect(user.reload.valid_password?(new_password)).to be(true)
        expect(response).to redirect_to(decidim_routes.new_user_session_path)
        expect(session_key).to be_nil
        expect(user.sign_in_count).to eq(0)
      end
    end
  end

  describe "invitation acceptance" do
    let(:user) { create(:user, organization:) }
    let(:token) do
      user.invite!
      user.raw_invitation_token
    end

    before do
      put decidim_routes.user_invitation_path, params: { user: { invitation_token: token, password: new_password, password_confirmation: new_password } }
    end

    context "when submitted on the user's organization" do
      let(:target_host) { organization.host }

      it "accepts the invitation and signs in the user" do
        expect(user.reload).to be_invitation_accepted
        expect(session_key).to be_present
      end
    end

    context "when submitted on another organization" do
      let(:target_host) { other_organization.host }

      it "accepts the invitation without signing in the user" do
        expect(user.reload).to be_invitation_accepted
        expect(response).to redirect_to(decidim_routes.new_user_session_path)
        expect(session_key).to be_nil
        expect(user.sign_in_count).to eq(0)
      end
    end
  end
end
