# frozen_string_literal: true

# This patch forces `html_escape: true` at the presenter boundary
Rails.application.config.to_prepare do
  Decidim::Proposals::ProposalPresenter

  module ProposalPresenterAlwaysEscapeTitle
    # rubocop:disable Lint/UnusedMethodArgument
    def title(html_escape: false, all_locales: false)
      super(html_escape: true, all_locales:)
    end
    # rubocop:enable Lint/UnusedMethodArgument
  end

  Decidim::Proposals::ProposalPresenter.prepend(ProposalPresenterAlwaysEscapeTitle)

  # The presenter above already escapes the title, so don't escape it twice
  module MentionResourceRendererEscapeTitleOnce
    def mention_title(resource)
      "<span class='editor-mention'>
          #{mention_avatar(resource)}
          <span>#{presenter_for(resource).title}</span>
        </span>".html_safe
    end
  end

  Decidim::ContentRenderers::MentionResourceRenderer.prepend(MentionResourceRendererEscapeTitleOnce)
end
