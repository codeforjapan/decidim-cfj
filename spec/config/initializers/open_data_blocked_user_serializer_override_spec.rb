# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Decidim::Exporters::OpenDataBlockedUserSerializer nil blocking override" do
  subject { Decidim::Exporters::OpenDataBlockedUserSerializer.new(user_moderation).serialize }

  let(:organization) { create(:organization) }

  context "when the blocked user has an associated Decidim::UserBlock" do
    let!(:user_block) { create(:user_block, organization:) }
    let(:user_moderation) { create(:user_moderation, user: user_block.user) }

    it "serializes the block reasons and the blocking user" do
      expect(subject[:block_reasons]).to eq(user_block.justification)
      expect(subject[:blocking_user]).to eq(user_block.blocking_user.presenter.name)
    end
  end

  # decidim-core/lib/decidim/core.rb の open_data_manifests は decidim_users.blocked_at で
  # 絞り込むが、serializer は decidim_users.block_id 経由の has_one :blocking を前提にしている。
  # block_id が NULL のまま blocked_at だけ入っているユーザーで NoMethodError にならないこと。
  context "when the user is blocked but has no associated Decidim::UserBlock" do
    let(:blocked_user) { create(:user, :blocked, :confirmed, organization:) }
    let(:user_moderation) { create(:user_moderation, user: blocked_user) }

    it "has no blocking association" do
      expect(blocked_user.block_id).to be_nil
      expect(blocked_user.blocking).to be_nil
    end

    it "does not raise and leaves the block columns empty" do
      expect { subject }.not_to raise_error
      expect(subject[:block_reasons]).to be_nil
      expect(subject[:blocking_user]).to be_nil
    end

    it "still serializes the user attributes" do
      expect(subject[:user_id]).to eq(blocked_user.id)
      expect(subject[:blocked_at]).to be_present
    end
  end
end
