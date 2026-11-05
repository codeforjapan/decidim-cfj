# frozen_string_literal: true

require "rails_helper"

# Verifies that the bulk block/unblock endpoints on `Decidim::Admin::BlockUserController`
#
# These specs lock down the cfj override that restores the check.
RSpec.describe "Decidim::Admin BlockUserController bulk actions" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user, :admin, :confirmed, organization:) }
  let(:user_manager_user) { create(:user, :user_manager, :confirmed, organization:) }
  let(:target_user) { create(:user, :confirmed, organization:) }
  let(:other_target) { create(:user, :confirmed, organization:) }

  before { host! organization.host }

  describe "POST bulk_create" do
    let(:params) do
      {
        user_ids: [target_user.id, other_target.id],
        justification: "Spam bot accounts detected over multiple posts"
      }
    end

    context "with a user_manager (dashboard access, no :block :admin_user permission)" do
      before { sign_in user_manager_user, scope: :user }

      it "does not block the target users" do
        post decidim_admin.bulk_create_moderated_users_path, params: params

        expect(target_user.reload.blocked).to be false
        expect(other_target.reload.blocked).to be false
      end

      it "does not create UserBlock records" do
        expect do
          post decidim_admin.bulk_create_moderated_users_path, params: params
        end.not_to change(Decidim::UserBlock, :count)
      end
    end

    context "with an organization admin" do
      before { sign_in admin_user, scope: :user }

      it "blocks the target users" do
        post decidim_admin.bulk_create_moderated_users_path, params: params

        expect(target_user.reload.blocked).to be true
        expect(other_target.reload.blocked).to be true
      end
    end
  end

  describe "DELETE bulk_destroy" do
    let(:blocked_target) do
      create(:user, :confirmed, :blocked, organization:).tap do |user|
        block = create(:user_block, user:, blocking_user: admin_user)
        user.update!(block_id: block.id)
      end
    end
    let(:params) { { user_ids: [blocked_target.id] } }

    context "with a user_manager" do
      before do
        blocked_target
        sign_in user_manager_user, scope: :user
      end

      it "does not unblock the target user" do
        delete decidim_admin.bulk_destroy_moderated_users_path, params: params

        expect(blocked_target.reload.blocked).to be true
      end
    end

    context "with an organization admin" do
      before do
        blocked_target
        sign_in admin_user, scope: :user
      end

      it "unblocks the target user" do
        delete decidim_admin.bulk_destroy_moderated_users_path, params: params

        expect(blocked_target.reload.blocked).to be false
      end
    end
  end
end
