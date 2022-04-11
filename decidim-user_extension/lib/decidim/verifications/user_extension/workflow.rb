# frozen_string_literal: true

Decidim::Verifications.register_workflow(:user_extension) do |workflow|
  workflow.engine = Decidim::Verifications::UserExtension::Engine
  workflow.admin_engine = Decidim::Verifications::UserExtension::AdminEngine
end
