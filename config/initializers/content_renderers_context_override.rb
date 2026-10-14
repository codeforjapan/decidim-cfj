# frozen_string_literal: true

# Backport of decidim/decidim#16545 to v0.30:
# "Fix content renderers with DOM-aware replacement to respect HTML context".
#
# Content renderers used to gsub Global ID patterns through the whole content
# without looking at the surrounding HTML. That broke two things:
#
#   1. A GID appearing in an href/src attribute got the full HTML replacement
#      (wrapper tags included), corrupting the attribute, e.g. adding a link
#      to a proposal over some text stored <a href="<span>...</span>">.
#   2. A GID inside <code>, <pre>, <script> or <style> was still replaced,
#      even though those are literal contexts.
#
# The fix moves the replacement into a shared, DOM-aware helper on
# BaseRenderer: it parses the content with the existing html_fragment,
# distinguishes text nodes from attributes and skips the protected ancestors.
# BlobRenderer, ResourceRenderer (the common parent of ProposalRenderer and
# MeetingRenderer) and UserRenderer (also UserGroupRenderer) then use it.
#
# MentionResourceRenderer does not exist in 0.30.9 (resource mentions are
# handled by the ResourceRenderer subclasses here), so nothing is ported for it.
#
# Fixed upstream in 0.31 (#16545 was not backported to release/0.30-stable,
# and 0.30.9 is the last 0.30 release), so it has to live here.
#
# Removal: delete this file and its spec once Decidim is 0.31 or newer. The
# guard below fails the boot on any other series so the leftover is noticed.
if Gem::Version.new(Decidim::Core.version).segments.first(2) != [0, 30]
  raise "content_renderers_context_override.rb and its spec should be removed in 0.31.x (decidim/decidim#16545)"
end

Rails.application.config.to_prepare do
  # Constants cannot be defined by assigning inside a class_eval block (the
  # assignment would leak to the block's lexical scope), so use const_set on
  # the class and reference them fully qualified from the method bodies.
  unless Decidim::ContentRenderers::BaseRenderer.const_defined?(:ReplacementContext, false)
    Decidim::ContentRenderers::BaseRenderer.const_set(
      :ReplacementContext,
      Struct.new(:placement, :node_name, :attribute_name, :ancestor_names, keyword_init: true) do
        def text?
          placement == :text
        end

        def attribute?
          placement == :attribute
        end
      end
    )
  end

  # decidim-core/lib/decidim/content_renderers/base_renderer.rb
  Decidim::ContentRenderers::BaseRenderer.class_eval do
    protected

    def replace_pattern_by_context(text, pattern, skip_ancestor_tags: %w(code pre script style), on_missing: "")
      return text unless text.respond_to?(:gsub)

      skip_ancestor_tags = Array(skip_ancestor_tags).map(&:to_s)

      has_match = pattern.is_a?(String) ? text.include?(pattern) : pattern.match?(text)
      return text unless has_match

      fragment = html_fragment(text)
      attr_modified = replace_pattern_in_attributes(fragment, pattern, skip_ancestor_tags:, on_missing:) do |match, context|
        yield(match, context)
      end
      text_modified = replace_pattern_in_text_nodes(fragment, pattern, skip_ancestor_tags:, on_missing:) do |match, context|
        yield(match, context)
      end

      return text unless attr_modified || text_modified

      fragment.to_s
    end

    private

    def replace_pattern_in_attributes(fragment, pattern, skip_ancestor_tags:, on_missing:)
      modified = false
      fragment.xpath(".//*").each do |node|
        next if skip_replacement_for_node?(node, skip_ancestor_tags)

        node.attribute_nodes.each do |attribute|
          replaced_value = attribute.value.gsub(pattern) do |match|
            replace_match(match, replacement_context(node, placement: :attribute, attribute_name: attribute.name), on_missing:) do |resolved_match, context|
              yield(resolved_match, context)
            end
          end
          unless replaced_value == attribute.value
            attribute.value = replaced_value
            modified = true
          end
        end
      end
      modified
    end

    def replace_pattern_in_text_nodes(fragment, pattern, skip_ancestor_tags:, on_missing:)
      modified = false
      fragment.xpath(".//text()").each do |node|
        parent = node.parent
        next if skip_replacement_for_node?(parent, skip_ancestor_tags)

        original_text = node.text
        has_node_match = pattern.is_a?(String) ? original_text.include?(pattern) : pattern.match?(original_text)
        next unless has_node_match

        doc = node.document
        context = replacement_context(parent, placement: :text)
        last_pos = 0

        original_text.scan(pattern) do
          m = Regexp.last_match
          node.add_previous_sibling(Nokogiri::XML::Text.new(original_text[last_pos...m.begin(0)], doc)) if m.begin(0) > last_pos

          replacement = replace_match(m[0], context, on_missing:) do |resolved_match, ctx|
            yield(resolved_match, ctx)
          end

          Loofah.fragment(replacement.to_s).children.to_a.each do |child|
            node.add_previous_sibling(child)
          end

          last_pos = m.end(0)
        end

        node.add_previous_sibling(Nokogiri::XML::Text.new(original_text[last_pos..], doc)) if last_pos < original_text.length
        node.remove
        modified = true
      end
      modified
    end

    def replace_match(match, context, on_missing:)
      yield(match, context)
    rescue ActiveRecord::RecordNotFound
      on_missing.respond_to?(:call) ? on_missing.call(match, context) : on_missing
    end

    def replacement_context(node, placement:, attribute_name: nil)
      Decidim::ContentRenderers::BaseRenderer::ReplacementContext.new(
        placement:,
        node_name: node&.name,
        attribute_name:,
        ancestor_names: node ? node.ancestors.map(&:name) : []
      )
    end

    def skip_replacement_for_node?(node, skip_ancestor_tags)
      return false unless node

      ([node.name] + node.ancestors.map(&:name)).any? { |name| skip_ancestor_tags.include?(name) }
    end
  end

  # decidim-core/lib/decidim/content_renderers/blob_renderer.rb
  Decidim::ContentRenderers::BlobRenderer.class_eval do
    protected

    def replace_pattern(text, pattern)
      replace_pattern_by_context(text, pattern) do |match, _context|
        match_data = match.match(pattern)
        blob_gid = match_data[1]
        variation_key = match_data[3]

        blob = GlobalID::Locator.locate(blob_gid)
        if variation_key
          variation = begin
            ActiveSupport::JSON.decode(Base64.strict_decode64(variation_key))
          rescue JSON::ParseError
            variation_key
          end
          blob_url(blob, variation)
        else
          blob_url(blob)
        end
      end
    end
  end

  # decidim-core/lib/decidim/content_renderers/resource_renderer.rb
  Decidim::ContentRenderers::ResourceRenderer.class_eval do
    def render(_options = nil)
      replace_pattern_by_context(content, regex, on_missing: proc { |match, _| "~#{match.split("/").last}" }) do |resource_gid, context|
        resource = GlobalID::Locator.locate(resource_gid)

        if context.attribute?
          resource_attribute_value(resource)
        else
          resource.presenter.display_mention
        end
      end
    end

    protected

    def resource_attribute_value(resource)
      presenter = resource.presenter
      return presenter.profile_path if presenter.respond_to?(:profile_path)

      Decidim::ResourceLocatorPresenter.new(resource).path
    end
  end

  # decidim-core/lib/decidim/content_renderers/user_renderer.rb
  Decidim::ContentRenderers::UserRenderer.class_eval do
    protected

    def replace_pattern(text, pattern, editor:)
      replace_pattern_by_context(text, pattern) do |user_gid, context|
        user = GlobalID::Locator.locate(user_gid)
        if context.attribute?
          render_profile_path(user)
        elsif editor
          render_editor(user)
        else
          render_text(user)
        end
      end
    end

    def render_profile_path(user)
      presenter_for(user).profile_path
    end
  end
end
