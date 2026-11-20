# frozen_string_literal: true

# ログイン・利用者登録・パスワード再設定などの画面（Devise のコントローラー）は
# Decidim::ApplicationController を継承しないため、Content-Security-Policy ヘッダーが付かない。
# ほかの画面と同じ CSP を付ける。decidim_awesome が足す許可先（Intergram など）も同じく付ける。
Rails.application.config.to_prepare do
  [
    Decidim::Devise::SessionsController,
    Decidim::Devise::RegistrationsController,
    Decidim::Devise::PasswordsController,
    Decidim::Devise::ConfirmationsController,
    Decidim::Devise::UnlocksController,
    Decidim::Devise::InvitationsController,
    Decidim::Devise::OmniauthRegistrationsController
  ].each do |controller|
    # after_action は後に登録したものから動くので、ヘッダーを書く concern を先に include する。
    [Decidim::Headers::ContentSecurityPolicy, Decidim::DecidimAwesome::ContentSecurityPolicy].each do |concern|
      controller.include(concern) unless controller.include?(concern)
    end
  end
end
