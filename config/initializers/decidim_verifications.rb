# frozen_string_literal: true

Decidim::Verifications.register_workflow(:user_extension_authorization_handler) do |workflow|
  workflow.form = "UserExtensionAuthorizationHandler"
end
