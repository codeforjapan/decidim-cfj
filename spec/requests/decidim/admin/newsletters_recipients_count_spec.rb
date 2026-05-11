# frozen_string_literal: true

require "rails_helper"

# Verifies that `Decidim::Admin::NewslettersController#recipients_count`
RSpec.describe "Decidim::Admin NewslettersController recipients_count" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user, :admin, :confirmed, organization:) }
  let(:user_manager_user) { create(:user, :user_manager, :confirmed, organization:) }
  let(:newsletter) { create(:newsletter, organization:, author: admin_user) }
  let(:params) { { newsletter: { send_to_all_users: true } } }

  before { host! organization.host }

  describe "POST recipients_count" do
    context "with a user_manager" do
      before { sign_in user_manager_user, scope: :user }

      it "does not return the recipients count" do
        post decidim_admin.recipients_count_newsletter_path(newsletter), params: params

        expect(response).not_to have_http_status(:ok)
      end
    end

    context "with an organization admin" do
      before { sign_in admin_user, scope: :user }

      it "returns the recipients count" do
        post decidim_admin.recipients_count_newsletter_path(newsletter), params: params

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
