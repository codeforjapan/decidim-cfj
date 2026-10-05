# frozen_string_literal: true

# 表示経路の content_handle_locale は Hashtag と Link しか通さないため、href に
# 入った gid が解決されないまま sanitize に入り、許可プロトコル外として href ごと
# 削除される。sanitize より後では手遅れなので super に渡す前に解決する。
#
# content_renderers_context_override.rb (decidim/decidim#16545 のバックポート)が
# 前提。素の ResourceRenderer は display_mention を gsub で差し込むため、href の
# 中に <a> タグが入って属性が壊れる。撤去するなら両方まとめて。
#
# 上流は 0.31 / 0.32 でも Blob と Link しか通しておらず未解消。
module DecidimCfjContentHandleLocaleResourceRenderers
  RESOURCE_RENDERERS = [
    "Decidim::ContentRenderers::ProposalRenderer",
    "Decidim::ContentRenderers::MeetingRenderer"
  ].freeze

  def content_handle_locale(body, all_locales, extras, links, strip_tags)
    super(resolve_resource_gids(body), all_locales, extras, links, strip_tags)
  end

  private

  def resolve_resource_gids(body)
    case body
    when String then render_resource_gids(body)
    when Hash then body.transform_values { |v| v.is_a?(String) ? render_resource_gids(v) : v }
    else body
    end
  end

  def render_resource_gids(content)
    # presenter は一覧表示で多数回呼ばれるため、gid が無ければレンダラを起動しない。
    return content unless content.include?("gid://")

    RESOURCE_RENDERERS.reduce(content) do |text, class_name|
      renderer_class = class_name.safe_constantize
      next text if renderer_class.blank?

      renderer_class.new(text).render
    end
  end
end

Rails.application.config.to_prepare do
  Decidim::SanitizeHelper.prepend(DecidimCfjContentHandleLocaleResourceRenderers) unless
    Decidim::SanitizeHelper.include?(DecidimCfjContentHandleLocaleResourceRenderers)
end
