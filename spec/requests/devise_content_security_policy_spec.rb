# frozen_string_literal: true

require "rails_helper"

# config/initializers/devise_content_security_policy.rb
RSpec.describe "Content-Security-Policy on Devise pages" do
  let(:organization) { create(:organization, content_security_policy: { "frame-src" => "embed.example.org" }) }
  let(:decidim_routes) { Decidim::Core::Engine.routes.url_helpers }
  let(:user) { create(:user, :confirmed, organization:) }

  before { host! organization.host }

  def csp
    response.headers["Content-Security-Policy"]
  end

  {
    "sign in" => -> { decidim_routes.new_user_session_path },
    "sign up" => -> { decidim_routes.new_user_registration_path },
    "password reset" => -> { decidim_routes.new_user_password_path },
    "password change" => -> { decidim_routes.edit_user_password_path(reset_password_token: user.send_reset_password_instructions) },
    "confirmation" => -> { decidim_routes.new_user_confirmation_path },
    "unlock" => -> { decidim_routes.new_user_unlock_path },
    "invitation" => lambda {
      invited = Decidim::User.invite!(email: "invited@example.org", name: "Invited", organization:, tos_agreement: true)
      decidim_routes.accept_user_invitation_path(invitation_token: invited.raw_invitation_token)
    }
  }.each do |page, path|
    it "adds the organization's CSP to the #{page} page" do
      get instance_exec(&path)

      expect(response).to have_http_status(:ok)
      expect(csp).to include("default-src 'self'")
      expect(csp).to include("embed.example.org")
    end
  end

  it "adds the same CSP as the other pages" do
    get decidim_routes.root_path
    root_csp = csp

    get decidim_routes.new_user_session_path

    expect(root_csp).to be_present
    expect(csp).to eq(root_csp)
  end
end
