Rails.application.routes.draw do
  mount Decidim::UserExtension::Engine => "/decidim-user_extension"
end
