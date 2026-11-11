# frozen_string_literal: true

# Requires an emailed code before using the admin panel (see Decidim::NeedsAdminLoginCode).
# Enabled with DECIDIM_ADMIN_LOGIN_CODE_ENABLED.
Decidim::Core::Engine.routes.append do
  resource :admin_login_code, only: [:new, :create], controller: "/decidim/admin_login_codes" do
    post :deliver
  end
end

Rails.application.config.to_prepare do
  Decidim::Admin::ApplicationController.include(Decidim::NeedsAdminLoginCode)
  Decidim::AccountController.include(Decidim::NeedsAdminLoginCodeForEmailChange)

  # Tell the old address when an email change is requested, so that a change made by someone else
  # does not go unnoticed (see app/views/devise/mailer/email_changed.html.erb).
  # Set on the model, not on Devise: Decidim::System::Admin has no locale, organization or
  # unconfirmed_email, so its notification could not be rendered.
  Decidim::User.send_email_changed_notification = true
end

# Ask for the code again on every sign in. Warden keeps the session of the user scope when the
# user is dropped without a sign out (for example, after the password is changed elsewhere).
Warden::Manager.after_authentication do |_user, auth, opts|
  next unless opts[:scope] == :user && opts[:store] != false

  auth.session(:user).except!(Decidim::AdminLoginCodeSession::VERIFIED_KEY, Decidim::AdminLoginCodeSession::PENDING_KEY)
end
