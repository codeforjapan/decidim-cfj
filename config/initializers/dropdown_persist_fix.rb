# frozen_string_literal: true

Rails.application.config.to_prepare do
  Decidim::ApplicationController.class_eval do
    before_action :add_dropdown_persist_fix_snippet

    private

    def add_dropdown_persist_fix_snippet
      return unless respond_to?(:snippets)
      return if @dropdown_persist_fix_snippet_added

      @dropdown_persist_fix_snippet_added = true
      # javascript_pack_tag can only be called once per page (Shakapacker's guard is per-request, not per pack), and decidim-dev's NeedsDevelopmentTools already uses that call — so resolve the path directly instead.
      path = helpers.asset_pack_path("decidim_cfj_dropdown_persist_fix.js")
      snippets.add(:foot, helpers.javascript_include_tag(path, defer: false))
    end
  end
end
