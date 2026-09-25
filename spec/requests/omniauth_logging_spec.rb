# frozen_string_literal: true

require "rails_helper"

# A Request spec for OmniAuth audit logging
#
# Using real middleware stacks (OmniAuth::Builder → strategy → Devise →
# Decidim::Devise::OmniauthRegistrationsController).
RSpec.describe "OmniAuth audit logging" do
  let(:organization) do
    create(:organization, omniauth_settings: {
             "omniauth_settings_line_login_enabled" => true,
             "omniauth_settings_line_login_client_id" => Decidim::AttributeEncryptor.encrypt("fake-line-channel-id"),
             "omniauth_settings_line_login_client_secret" => Decidim::AttributeEncryptor.encrypt("fake-line-channel-secret")
           })
  end
  let(:log_output) { StringIO.new }
  let(:logged) { log_output.string }

  let(:callback_path) { "/users/auth/line_login/callback" }
  let(:uid) { "U1234567890abcdef" }
  let(:email) { "taro@example.org" }
  let(:auth_hash) do
    OmniAuth::AuthHash.new(
      provider: "line_login",
      uid:,
      info: {
        name: "山田太郎",
        nickname: "taro",
        email:,
        image: "https://profile.line-scdn.net/xxxxx"
      },
      credentials: { token: "SECRET_ACCESS_TOKEN", refresh_token: "SECRET_REFRESH_TOKEN" }
    )
  end

  around do |example|
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(log_output)
    OmniAuth.config.test_mode = true
    example.run
  ensure
    Rails.logger = original_logger
    OmniAuth.config.mock_auth.delete(:line_login)
    OmniAuth.config.test_mode = false
  end

  before do
    host! organization.host
    OmniAuth.config.mock_auth[:line_login] = auth_hash

    # for AvatarFetcher in decidim-user_extension
    stub_request(:get, "https://profile.line-scdn.net/xxxxx").to_return(
      status: 200,
      body: File.binread(Decidim::Dev.asset("avatar.jpg")),
      headers: { "Content-Type" => "image/jpeg" }
    )
  end

  describe "認証が成功し、ユーザー登録も通る場合" do
    it "callback と registration の両方を記録する" do
      get callback_path

      # CreateOmniauthRegistration raises NeedTosAcceptance and renders new_tos_fields,
      # so registration is pending.
      expect(logged).to include("[omniauth] phase=callback result=ok")
      expect(logged).to include("[omniauth] phase=registration result=pending")

      post "/omniauth_registrations", params: {
        user: {
          provider: "line_login",
          uid:,
          name: "山田太郎",
          nickname: "taro",
          email:,
          oauth_signature: Decidim::OmniauthRegistrationForm.create_signature("line_login", uid),
          tos_agreement: "1"
        }
      }

      expect(logged).to include("[omniauth] phase=registration result=ok")
    end

    # OmniAuth::Builder が複数積まれているため、素朴に書くと provider 数だけ
    # 同じ行が出てしまう。1 ログイン = 1 行であることを固定する。
    it "ログを重複させない" do
      get callback_path

      expect(logged.scan("phase=callback result=ok").size).to eq(1)
      expect(logged.scan("phase=registration").size).to eq(1)
    end

    it "provider / uid / request_id を記録する" do
      get callback_path

      expect(logged).to include("provider=line_login")
      expect(logged).to include("uid=#{uid}")
      expect(logged).to match(/request_id=\h{8}-\h{4}/)
    end

    it "アクセストークンを記録しない" do
      get callback_path

      expect(logged).not_to include("SECRET_ACCESS_TOKEN")
      expect(logged).not_to include("SECRET_REFRESH_TOKEN")
    end

    it "表示名・メールアドレス・プロフィール画像を記録しない" do
      get callback_path

      expect(logged).not_to include("山田太郎")
      expect(logged).not_to include(email)
      expect(logged).not_to include("profile.line-scdn.net")
      expect(logged).to include("email_from_idp=true")
    end
  end

  describe "既にそのメールアドレスの利用者がいる場合" do
    before { create(:user, :confirmed, organization:, email:) }

    it "既存アカウントに identity を紐付けて成功として記録する" do
      get callback_path

      expect(logged).to include("[omniauth] phase=registration result=ok")
    end
  end

  describe "IdP がメールアドレスを返さない場合" do
    let(:auth_hash) do
      OmniAuth::AuthHash.new(
        provider: "line_login", uid:, info: { name: "山田太郎", nickname: "taro" }
      )
    end

    it "callback は成功、registration は invalid として記録する" do
      get callback_path

      expect(logged).to include("[omniauth] phase=callback result=ok")
      expect(logged).to include("email_from_idp=false")
      expect(logged).to include("[omniauth] phase=registration result=invalid")
    end

    it "どの属性で弾かれたかを記録する" do
      get callback_path

      expect(logged).to include("errors=email")
      expect(logged).to include("uid=#{uid}")
    end

    it "表示名を記録しない" do
      get callback_path

      expect(logged).not_to include("山田太郎")
    end
  end

  describe "OmniAuth 側で認証が失敗した場合" do
    # should use on_failure in Devise
    let(:auth_hash) { :invalid_credentials }

    it "失敗を warn で記録する" do
      get callback_path

      expect(logged).to include("[omniauth] phase=callback result=failure")
      expect(logged).to include("provider=line_login")
      expect(logged).to include("type=invalid_credentials")
    end

    it "成功として記録しない" do
      get callback_path

      expect(logged).not_to include("result=ok")
    end

    describe "利用者が IdP でキャンセルした場合" do
      let(:auth_hash) { :access_denied }

      it "キャンセルであることを記録する" do
        get callback_path

        expect(logged).to include("type=access_denied")
      end
    end
  end

  describe "CfjOmniauthFailureLogging" do
    it "長すぎる例外メッセージを切り詰める" do
      error = StandardError.new("x" * 500)
      CfjOmniauthFailureLogging.log("omniauth.error" => error, "omniauth.error.type" => :invalid_credentials)

      expect(logged).to include("x" * 197)
      expect(logged).not_to include("x" * 201)
    end

    it "二重に適用しない" do
      expect { CfjOmniauthFailureLogging.install! }
        .not_to(change { OmniAuth.config.on_failure })
    end
  end
end
