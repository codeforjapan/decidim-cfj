# frozen_string_literal: true

class PurgeComponentCacheJob < ApplicationJob
  def perform(component_id)
    component = Decidim::Component.find(component_id)
    clear_all_related_caches(component)
  end

  private

  def clear_all_related_caches(_component)
    patterns = [
      "cells/decidim/comments/comment_form/*"
    ]

    patterns.each do |pattern|
      count = Rails.cache.delete_matched(pattern)
      Rails.logger.info "Purged #{count} cache entries matching #{pattern}"
    end
  end
end
