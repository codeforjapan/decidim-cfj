# frozen_string_literal: true

Rails.application.config.to_prepare do
  # Override :comments_count on accountability_component.
  accountability_component = Decidim.find_component_manifest(:accountability)
  accountability_component.stats.stats.reject! { |s| s[:name] == :comments_count }
  accountability_component.register_stat :comments_count, tag: :comments do |components, start_at, end_at|
    results = Decidim::Accountability::FilteredResults.for(components, start_at, end_at)
    results.sum(:comments_count)
  end

  # Override :comments_count on blogs_component.
  blogs_component = Decidim.find_component_manifest(:blogs)
  blogs_component.stats.stats.reject! { |s| s[:name] == :comments_count }
  blogs_component.register_stat :comments_count, tag: :comments do |components, start_at, end_at|
    posts = Decidim::Blogs::FilteredPosts.for(components, start_at, end_at)
    posts.sum(:comments_count)
  end

  # Override :comments_count on debates_component.
  debates_component = Decidim.find_component_manifest(:debates)
  debates_component.stats.stats.reject! { |s| s[:name] == :comments_count }
  debates_component.register_stat :comments_count, tag: :comments do |components, start_at, end_at|
    debates = Decidim::Debates::FilteredDebates.for(components, start_at, end_at)
    debates.sum(:comments_count)
  end

  # Override :comments_count on sortitions_component.
  sortitions_component = Decidim.find_component_manifest(:sortitions)
  sortitions_component.stats.stats.reject! { |s| s[:name] == :comments_count }
  sortitions_component.register_stat :comments_count, tag: :comments do |components, start_at, end_at|
    sortitions = Decidim::Sortitions::FilteredSortitions.for(components, start_at, end_at)
    sortitions.sum(:comments_count)
  end
end
