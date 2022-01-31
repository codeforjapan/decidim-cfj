# frozen_string_literal: true

# Override Decidim::Orderable
#
# Use cookies to store default orders
Decidim::Proposals::ProposalsController.prepend Decidim::Proposals::CookieOrderable
