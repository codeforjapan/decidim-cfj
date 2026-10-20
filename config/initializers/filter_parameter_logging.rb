# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
# Rails 7 defaults, plus :code for verification and OAuth codes and :unique_id
# for authorizations.
Rails.application.config.filter_parameters += [
  :passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :code, :unique_id
]

# Redirect locations can carry a token or an OAuth authorization code: back to
# an invitation or reset password URL (e.g. after POST /locale), or to an OAuth
# client after authorization. Copies URL-encoded inside another parameter, once
# or more, are matched too.
Rails.application.config.filter_redirect << /(?:token|code)(?:=|%(?:25)*3D)/i

Rails.application.config.after_initialize do
  # ActiveRecord copies filter_parameters when it is loaded, which happens
  # before this file runs, so #inspect of models would still show them.
  ActiveRecord::Base.filter_attributes |= Rails.application.config.filter_parameters

  # Devise mails (reset password, invitation, confirmation) and the newsletter
  # opt-in confirmation carry raw tokens as arguments, which ActiveJob logs on
  # enqueue and perform. 0.32 delivers all of them through MailDeliveryJob:
  # Decidim::NewslettersOptInJob is gone and decidim_newsletterable calls
  # NewslettersOptInMailer#notify with deliver_later.
  ActionMailer::MailDeliveryJob.log_arguments = false
end
