# frozen_string_literal: true

module DecidimCfjContentHandleLocaleResourceRenderers
  private

  # The signature differs between versions (0.31 drops `extras`), so pass the rest through.
  def content_handle_locale(body, *)
    super(resolve_resource_gids(body), *)
  end

  def resolve_resource_gids(body)
    case body
    when Hash
      body.transform_values { |value| resolve_resource_gids(value) }
    else
      DecidimCfjEditorResourceLink.rewrite(body, public_only: true)
    end
  end
end

Rails.application.config.to_prepare do
  Decidim::SanitizeHelper.prepend(DecidimCfjContentHandleLocaleResourceRenderers) unless
    Decidim::SanitizeHelper.include?(DecidimCfjContentHandleLocaleResourceRenderers)
end
