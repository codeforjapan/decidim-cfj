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

  # The presenter above already escapes the title, so make sure it is escaped only once
  module MentionResourceRendererEscapeTitleOnce
    def mention_title(resource)
      "<span class='editor-mention'>
          #{mention_avatar(resource)}
          <span>#{presenter_for(resource).title}</span>
        </span>".html_safe
    end

    def render_editor(resource_gid, resource)
      escaped_gid = CGI.escapeHTML(resource_gid.to_s)
      title = CGI.escapeHTML(CGI.unescapeHTML(presenter_for(resource).title.to_s))

      %(<span data-type="mentionResource" data-id="#{escaped_gid}" data-label="#{title}">#{title}</span>)
    end
  end

  Decidim::ContentRenderers::MentionResourceRenderer.prepend(MentionResourceRendererEscapeTitleOnce)
end
