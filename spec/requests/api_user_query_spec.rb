# frozen_string_literal: true

require "rails_helper"

# Covers config/initializers/api_user_query_hardening.rb.
RSpec.describe "GraphQL user query" do
  let(:organization) { create(:organization) }
  let!(:user) { create(:user, :confirmed, organization:, nickname: "hanako", name: "山田花子") }

  def execute(query)
    Decidim::Api::Schema.execute(
      query,
      context: { current_organization: organization, current_user: nil }
    ).to_h
  end

  it "returns nothing when called without arguments" do
    expect(execute("{ user { name } }")["data"]).to eq("user" => nil)
  end

  it "returns nothing when the arguments are blank" do
    expect(execute(%({ user(nickname: "") { name } }))["data"]).to eq("user" => nil)
  end

  it "still resolves a participant by nickname" do
    expect(execute(%({ user(nickname: "hanako") { name } }))["data"]).to eq("user" => { "name" => "山田花子" })
  end

  it "still resolves a participant by id" do
    expect(execute(%({ user(id: "#{user.id}") { name } }))["data"]).to eq("user" => { "name" => "山田花子" })
  end
end
