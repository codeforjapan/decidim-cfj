# frozen_string_literal: true

Decidim::Verifications.register_workflow(:user_extension) do |workflow|
  workflow.form = "UserExtensionAuthorizationHandler"
end
