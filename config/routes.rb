# frozen_string_literal: true

require "sidekiq/web"
Rails.application.routes.draw do
  # Redirect to Metadecidim Japan
  get "/", to: redirect("https://meta.diycities.jp/"), constraints: { host: "www.diycities.jp" }
  get "/search", to: redirect("/")

  mount Decidim::Core::Engine => "/"
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  authenticate :user, ->(u) { u.admin? } do
    mount Sidekiq::Web => "/sidekiq"
  end

  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
end
