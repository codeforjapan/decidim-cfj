# frozen_string_literal: true

Rails.application.config.to_prepare do
  # Add :comment_count to accountability_component's stat
  accountability_component = Decidim.find_component_manifest(:accountability)
  accountability_component.register_stat :comments_count, tag: :comments do |components, start_at, end_at|
    results = Decidim::Accountability::FilteredResults.for(components, start_at, end_at)
    results.sum(:comments_count)
  end

  # Add :comment_count to blogs_component's stat
  blogs_component = Decidim.find_component_manifest(:blogs)
  blogs_component.register_stat :comments_count, tag: :comments do |components, start_at, end_at|
    posts = Decidim::Blogs::FilteredPosts.for(components, start_at, end_at)
    posts.sum(:comments_count)
  end

  # Add :comment_count to debates_component's stat
  debates_component = Decidim.find_component_manifest(:debates)
  debates_component.register_stat :comments_count, tag: :comments do |components, start_at, end_at|
    debates = Decidim::Debates::FilteredDebates.for(components, start_at, end_at)
    debates.sum(:comments_count)
  end

  # Add :comment_count to sortitions_component's stat
  sortitions_component = Decidim.find_component_manifest(:sortitions)
  sortitions_component.register_stat :comments_count, tag: :comments do |components, start_at, end_at|
    sortitions = Decidim::Sortitions::FilteredSortitions.for(components, start_at, end_at)
    sortitions.sum(:comments_count)
  end
end
