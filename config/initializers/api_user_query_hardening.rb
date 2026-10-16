# frozen_string_literal: true

# Backport of decidim/decidim#17468 for the GraphQL `user` query.
#
# Backported to release/0.31-stable (#17484) and release/0.32-stable (#17483),
# but *not released yet*: both branches still report their previous version
# (0.31.7 / 0.32.1), so every version we can actually run still needs this
# patch. release/0.30-stable stopped taking backports before it landed.
#
# Removal: delete this file and its spec once Decidim reaches the first version
# that ships the fix in its own release series. The guard below fails the boot
# from that version on — and on any series we have not checked — so the
# leftover is noticed instead of silently shadowing a fixed upstream.
fixed_from = {
  "0.31" => "0.31.8",
  "0.32" => "0.32.2"
}

current_version = Gem::Version.new(Decidim::Core.version)
series = current_version.segments.first(2).join(".")
threshold = fixed_from[series]

if threshold.nil? || current_version >= Gem::Version.new(threshold)
  raise "api_user_query_hardening.rb and its spec should be removed, or #{series} added to fixed_from (decidim/decidim#17468)"
end

module DecidimCfjApiUserQueryPatch
  def user(id: nil, nickname: nil)
    return if id.blank? && nickname.blank?

    super
  end
end

Rails.application.config.to_prepare do
  Decidim::Api::QueryType

  Decidim::Api::QueryType.prepend(DecidimCfjApiUserQueryPatch)
end
