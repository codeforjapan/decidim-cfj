# frozen_string_literal: true

# node_modules is in additional_paths so that the packs of the Decidim gems,
# which live outside the app, can resolve npm packages. Shakapacker also
# watches every additional path to tell whether the packs are stale, which
# means hashing about 60,000 files in node_modules on each check. Changes there
# come from yarn.lock and package.json, which are watched anyway.
module ShakapackerWatchedPathsWithoutNodeModules
  private

  def default_watched_paths
    super.reject { |path| path.start_with?("node_modules{") }
  end
end

Shakapacker::BaseStrategy.prepend(ShakapackerWatchedPathsWithoutNodeModules)
