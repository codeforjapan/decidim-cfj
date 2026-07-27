# frozen_string_literal: true

require "rails_helper"

RSpec.describe OmniAuth::Strategies::LineLogin do
  subject(:strategy) { described_class.new(app, "channel-id", "channel-secret") }

  let(:app) { ->(_env) { [200, {}, ["ok"]] } }
  let(:session) { {} }
  let(:nonce) { "11111111-2222-3333-4444-555555555555" }
  let(:access_token) do
    OAuth2::AccessToken.new(strategy.client, "dummy-access-token", "id_token" => "dummy.id.token")
  end
  let(:env) do
    Rack::MockRequest.env_for("https://example.org/users/auth/line_login/callback?state=state-1&code=xyz")
  end

  before do
    allow(strategy).to receive(:session).and_return(session)
    session["omniauth.state"] = "state-1"
    strategy.instance_variable_set(:@env, env)
    allow(strategy).to receive_messages(build_access_token: access_token, fail!: :failed)
  end

  context "when the session has no nonce" do
    it "LINE に検証リクエストを送らない" do
      strategy.callback_phase

      expect(a_request(:post, "https://api.line.me/oauth2/v2.1/verify")).not_to have_been_made
    end

    it "500 にせずログイン失敗として扱う" do
      expect { strategy.callback_phase }.not_to raise_error

      expect(strategy).to have_received(:fail!)
        .with(:invalid_id_token, instance_of(OmniAuth::LineLogin::Error))
    end
  end

  context "when the session has a nonce" do
    before do
      session["omniauth.nonce"] = nonce
      stub_request(:post, "https://api.line.me/oauth2/v2.1/verify").to_return(
        status: 200,
        body: { "sub" => "U1234567890abcdef", "nonce" => nonce }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
    end

    it "検証リクエストに nonce を含める" do
      strategy.callback_phase

      expect(
        a_request(:post, "https://api.line.me/oauth2/v2.1/verify")
          .with { |req| req.body.include?("nonce=#{nonce}") }
      ).to have_been_made
    end

    it "失敗させず auth hash を組み立てる" do
      strategy.callback_phase

      expect(strategy).not_to have_received(:fail!)
      expect(env["omniauth.auth"]["uid"]).to eq("U1234567890abcdef")
    end
  end
end
