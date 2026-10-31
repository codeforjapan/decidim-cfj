# frozen_string_literal: true

require "rails_helper"

# Covers config/initializers/user_moderation_type_override.rb.
RSpec.describe "GraphQL moderatedUsers query" do
  let(:organization) { create(:organization) }

  # 0.31 以降の Decidim::Api::RequiredScopes#scope_authorized? が context[:scopes] を
  # 無条件に参照するため、未ログイン相当の api:read を渡す必要がある。
  let(:api_scopes) { Doorkeeper::OAuth::Scopes.from_string("api:read") }
  let(:query) { "{ moderatedUsers { blockReasons blockingUser { id } } }" }

  def execute(query)
    Decidim::Api::Schema.execute(
      query,
      context: { current_organization: organization, current_user: nil, scopes: api_scopes }
    ).to_h
  end

  context "when the blocked user has an associated Decidim::UserBlock" do
    let!(:user_block) { create(:user_block, organization:) }
    let!(:user_moderation) { create(:user_moderation, user: user_block.user) }

    it "resolves the block reasons and the blocking user" do
      result = execute(query)

      expect(result["errors"]).to be_nil
      expect(result["data"]["moderatedUsers"]).to contain_exactly(
        "blockReasons" => user_block.justification,
        "blockingUser" => { "id" => user_block.blocking_user.id.to_s }
      )
    end
  end

  # moderatedUsers の collection は decidim_users.blocked_at で絞り込むが、型のリゾルバは
  # decidim_users.block_id 経由の has_one :blocking を前提にしている。
  # block_id が NULL のまま blocked_at だけ入っているユーザーで例外にならないこと。
  context "when the user is blocked but has no associated Decidim::UserBlock" do
    let(:blocked_user) { create(:user, :blocked, :confirmed, organization:) }
    let!(:user_moderation) { create(:user_moderation, user: blocked_user) }

    it "has no blocking association" do
      expect(blocked_user.block_id).to be_nil
      expect(blocked_user.blocking).to be_nil
    end

    it "returns nulls instead of raising" do
      result = execute(query)

      expect(result["errors"]).to be_nil
      expect(result["data"]["moderatedUsers"]).to contain_exactly(
        "blockReasons" => nil,
        "blockingUser" => nil
      )
    end
  end
end
