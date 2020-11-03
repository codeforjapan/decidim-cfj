# frozen_string_literal: true

require "sidekiq/web"
Rails.application.routes.draw do
  mount Decidim::Core::Engine => "/"
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  authenticate :user, ->(u) { u.admin? } do
    mount Sidekiq::Web => "/sidekiq"
  end

  get "/admin/officializations/user_extensions/:user_id" =>
      "decidim/admin/officializations/user_extensions#show",
      constraints: (->(request) { Decidim::Admin::OrganizationDashboardConstraint.new(request).matches? }),
      as: "user_extension_admin_officialization"

  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
end
