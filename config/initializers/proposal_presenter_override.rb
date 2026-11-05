# frozen_string_literal: true

# This patch forces `html_escape: true` at the presenter boundary
Rails.application.config.to_prepare do
  Decidim::Proposals::ProposalPresenter # rubocop:disable Lint/Void

  module ProposalPresenterAlwaysEscapeTitle
    # rubocop:disable Lint/UnusedMethodArgument
    def title(links: false, extras: true, html_escape: false, all_locales: false)
      super(links:, extras:, html_escape: true, all_locales:)
    end
    # rubocop:enable Lint/UnusedMethodArgument
  end

  Decidim::Proposals::ProposalPresenter.prepend(ProposalPresenterAlwaysEscapeTitle)
end
