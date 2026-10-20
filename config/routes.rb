# frozen_string_literal: true

require "sidekiq/web"
Rails.application.routes.draw do
  # Redirect to Metadecidim Japan
  get "/", to: redirect("https://meta.diycities.jp/"), constraints: { host: "www.diycities.jp" }

  # Disable DM (private messaging / conversations) feature.
  # Redirect all conversation-related paths to the root with 301.
  match "/conversations(/*path)", to: redirect("/", status: 301), via: :all
  match "/profiles/:nickname/conversations(/*path)", to: redirect("/", status: 301), via: :all

  mount Decidim::Core::Engine => "/"
  # Sidekiq::Web exposes the queue to system admins only.
  authenticate :admin do
    mount Sidekiq::Web => "/sidekiq"
  end

  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
end
