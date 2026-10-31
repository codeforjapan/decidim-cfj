# frozen_string_literal: true

require "rails_helper"
require "decidim/verifications/test/factories"

RSpec.describe "Decidim::Admin ConflictsController organization scope" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user, :admin, :confirmed, organization:) }

  let(:other_organization) { create(:organization) }
  let(:other_user) { create(:user, :confirmed, organization: other_organization) }
  let!(:other_conflict) do
    create(
      :conflict,
      current_user: other_user,
      managed_user: create(:user, managed: true, organization: other_organization)
    )
  end

  let!(:own_conflict) do
    create(
      :conflict,
      current_user: create(:user, :confirmed, organization:),
      managed_user: create(:user, managed: true, organization:)
    )
  end

  before do
    host! organization.host
    sign_in admin_user, scope: :user
  end

  describe "GET edit" do
    it "does not render a conflict from another organization" do
      get decidim_admin.edit_conflict_path(other_conflict)

      expect(response).to have_http_status(:not_found)
    end

    it "renders a conflict from the current organization" do
      get decidim_admin.edit_conflict_path(own_conflict)

      expect(response).to have_http_status(:ok)
    end
  end

  # A conflict is recorded with the submitting user as current_user and the
  # holder of the matching authorization as managed_user, and those two can end
  # up in different organizations. The transfer writes to managed_user, so that
  # is the side the check has to cover.
  describe "PATCH update on a conflict whose managed user is elsewhere" do
    let(:params) { { transfer_user: { reason: "reason", email: "transferred@example.org" } } }

    let!(:mixed_conflict) do
      create(
        :conflict,
        current_user: create(:user, :confirmed, organization:),
        managed_user: create(:user, managed: true, organization: other_organization)
      )
    end

    it "does not transfer a managed user in another organization" do
      original_email = mixed_conflict.managed_user.email

      patch(decidim_admin.conflict_path(mixed_conflict), params:)

      expect(response).to have_http_status(:not_found)

      expect(mixed_conflict.managed_user.reload.email).to eq(original_email)
    end
  end

  describe "PATCH update" do
    let(:params) { { transfer_user: { reason: "reason", email: "transferred@example.org" } } }

    it "does not transfer a managed user in another organization" do
      original_email = other_conflict.managed_user.email

      patch(decidim_admin.conflict_path(other_conflict), params:)

      expect(response).to have_http_status(:not_found)

      expect(other_conflict.managed_user.reload.email).to eq(original_email)
      expect(other_conflict.reload.solved).to be_falsey
    end
  end
end
