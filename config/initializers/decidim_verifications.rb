# frozen_string_literal: true

Decidim::Verifications.register_workflow(:user_extension) do |workflow|
  workflow.engine = Decidim::UserExtension::Engine
  workflow.admin_engine = Decidim::UserExtension::AdminEngine
end
