# frozen_string_literal: true

# Backport of decidim/decidim#17468 for the GraphQL `user` query.
#
# Backported to release/0.31-stable (#17484) and release/0.32-stable (#17483),
# but *not released yet*: v0.31.7 (tagged 2026-07-30) and v0.32.1 both predate
# the fix, and release/0.30-stable stopped taking backports before it landed.
# So every version we can actually run still needs this patch.
#
# Removal: delete this file and its spec once Decidim is 0.31.8 or newer. The
# guard below fails the boot from that version on, so the leftover is noticed.
raise "api_user_query_hardening.rb and its spec should be removed (decidim/decidim#17468)" if Gem::Version.new(Decidim::Core.version) >= Gem::Version.new("0.31.8")

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
