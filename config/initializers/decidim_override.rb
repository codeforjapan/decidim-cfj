# frozen_string_literal: true

# Override Decidim::Orderable
#
# Use cookies to store default orders
#
Rails.application.config.to_prepare do
  Decidim::Proposals::ProposalsController.prepend Decidim::Proposals::CookieOrderable
end
