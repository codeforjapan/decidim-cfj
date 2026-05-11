# frozen_string_literal: true

require "rails_helper"

# Verifies that the bulk_unreport endpoint
RSpec.describe "Decidim::Admin ModeratedUsersController bulk_unreport" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user, :admin, :confirmed, organization:) }
  let(:user_manager_user) { create(:user, :user_manager, :confirmed, organization:) }
  let(:reported_user) { create(:user, :confirmed, organization:) }
  let!(:user_moderation) { create(:user_moderation, user: reported_user) }
  let(:params) { { user_ids: [reported_user.id] } }

  before { host! organization.host }

  describe "PATCH bulk_unreport" do
    context "with a user_manager (dashboard access, no :unreport :moderate_users permission)" do
      before { sign_in user_manager_user, scope: :user }

      it "does not dismiss the report" do
        patch decidim_admin.bulk_unreport_moderated_users_path, params: params

        expect(Decidim::UserModeration.exists?(user_moderation.id)).to be true
      end
    end

    context "with an organization admin" do
      before { sign_in admin_user, scope: :user }

      it "dismisses the report" do
        patch decidim_admin.bulk_unreport_moderated_users_path, params: params

        expect(Decidim::UserModeration.exists?(user_moderation.id)).to be false
      end
    end
  end
end
