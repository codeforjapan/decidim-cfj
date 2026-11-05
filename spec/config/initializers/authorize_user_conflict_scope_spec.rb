# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Decidim::Verifications::AuthorizeUser conflict scope" do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }

  let(:user) { create(:user, :confirmed, organization:) }

  # The identifying fields the handler hashes into unique_id. They carry no
  # organization component, so the same person produces the same value in every
  # organization of the installation.
  let(:identity) do
    { real_name: "Taro Yamada", address: "1-1 Chiyoda, Tokyo", birth_year: 1990, gender: 1 }
  end

  let(:shared_unique_id) do
    Decidim::UserExtensionForm.new(**identity, occupation: "Engineer", user:).unique_id
  end

  # Submitted from `organization`, but invalid (occupation is blank), which is
  # what routes AuthorizeUser into the conflict-registration branch.
  let(:handler) do
    Decidim::UserExtensionForm.new(**identity, occupation: "", user:)
  end

  def authorize
    Decidim::Verifications::AuthorizeUser.call(handler, organization)
  end

  it "builds a handler that is invalid and shares the unique_id" do
    expect(handler).to be_invalid
    expect(handler.unique_id).to eq(shared_unique_id)
  end

  context "when the matching authorization belongs to another organization" do
    let(:other_user) { create(:user, :confirmed, organization: other_organization) }
    let!(:other_authorization) do
      create(
        :authorization,
        :granted,
        user: other_user,
        name: "user_extension",
        unique_id: shared_unique_id
      )
    end

    it "does not record a conflict against that user" do
      expect { authorize }.not_to change(Decidim::Verifications::Conflict, :count)
    end
  end

  context "when the matching authorization belongs to the current organization" do
    let(:same_organization_user) { create(:user, :confirmed, organization:) }
    let!(:same_organization_authorization) do
      create(
        :authorization,
        :granted,
        user: same_organization_user,
        name: "user_extension",
        unique_id: shared_unique_id
      )
    end

    it "records a conflict against that user" do
      expect { authorize }.to change(Decidim::Verifications::Conflict, :count).by(1)

      conflict = Decidim::Verifications::Conflict.last
      expect(conflict.current_user).to eq(user)
      expect(conflict.managed_user).to eq(same_organization_user)
    end

    context "when an authorization in another organization shares the unique_id" do
      let(:other_user) { create(:user, :confirmed, organization: other_organization) }
      let!(:other_authorization) do
        create(
          :authorization,
          :granted,
          user: other_user,
          name: "user_extension",
          unique_id: shared_unique_id
        )
      end

      it "still records the conflict against the user in the current organization" do
        expect { authorize }.to change(Decidim::Verifications::Conflict, :count).by(1)

        expect(Decidim::Verifications::Conflict.last.managed_user).to eq(same_organization_user)
      end
    end
  end
end
