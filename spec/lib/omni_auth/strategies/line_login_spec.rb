# frozen_string_literal: true

require "rails_helper"

RSpec.describe OmniAuth::Strategies::LineLogin do
  subject(:strategy) { described_class.new(app, "channel-id", "channel-secret") }

  let(:app) { ->(_env) { [200, {}, ["ok"]] } }
  let(:nonce) { "11111111-2222-3333-4444-555555555555" }
  let(:state) { "state-1" }
  let(:session) { { "omniauth.state" => state } }
  let(:token_url) { "https://api.line.me/oauth2/v2.1/token" }
  let(:verify_url) { "https://api.line.me/oauth2/v2.1/verify" }
  let(:env) do
    Rack::MockRequest.env_for(
      "https://example.org/users/auth/line_login/callback?state=#{state}&code=authorization-code",
      "rack.session" => session
    )
  end

  # fail! は env にエラー情報を書いてから on_failure を呼ぶ。本物の on_failure は
  # Devise のコントローラに入ってしまうので、そこだけ差し替えて env を検証する。
  around do |example|
    original_on_failure = OmniAuth.config.on_failure
    OmniAuth.config.on_failure = ->(_env) { [302, {}, []] }
    example.run
  ensure
    OmniAuth.config.on_failure = original_on_failure
  end

  before do
    stub_request(:post, token_url).to_return(
      status: 200,
      body: {
        access_token: "dummy-access-token",
        token_type: "Bearer",
        expires_in: 2_592_000,
        id_token: "dummy.id.token"
      }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
  end

  def stub_verify(body)
    stub_request(:post, verify_url).to_return(
      status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" }
    )
  end

  context "when the session has no nonce" do
    it "LINE に検証リクエストを送らない" do
      strategy.call!(env)

      expect(a_request(:post, verify_url)).not_to have_been_made
    end

    it "ログイン失敗として扱う" do
      strategy.call!(env)

      expect(env["omniauth.error.type"]).to eq(:invalid_id_token)
      expect(env["omniauth.error"]).to be_a(OmniAuth::LineLogin::Error)
    end

    it "auth hash を組み立てない" do
      strategy.call!(env)

      expect(env["omniauth.auth"]).to be_nil
    end
  end

  context "when the session has a nonce" do
    before do
      session["omniauth.nonce"] = nonce
      stub_verify("sub" => "U1234567890abcdef", "nonce" => nonce)
    end

    it "検証リクエストに nonce を含める" do
      strategy.call!(env)

      expect(
        a_request(:post, verify_url).with { |req| req.body.include?("nonce=#{nonce}") }
      ).to have_been_made
    end

    it "失敗させず auth hash を組み立てる" do
      strategy.call!(env)

      expect(env["omniauth.error.type"]).to be_nil
      expect(env["omniauth.auth"]["uid"]).to eq("U1234567890abcdef")
    end
  end
end
