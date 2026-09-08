# frozen_string_literal: true

# Backport of decidim/decidim#17468 for the GraphQL `user` query.
#
# Fixed upstream in 0.31 (#17484) and 0.32 (#17483). release/0.30-stable stopped
# taking backports before it landed, so it has to live here.
#
# Removal: delete this file and its spec once Decidim is 0.31 or newer. The
# guard below fails the boot on any other series so the leftover is noticed.
raise "api_user_query_hardening.rb and its spec should be removed in 0.31.x (decidim/decidim#17468)" if Gem::Version.new(Decidim::Core.version).segments.first(2) != [0, 30]

module DecidimCfjApiUserQueryPatch
  def user(id: nil, nickname: nil)
    return if id.blank? && nickname.blank?

    super
  end
end

Rails.application.config.to_prepare do
  Decidim::Api::QueryType # rubocop:disable Lint/Void

  Decidim::Api::QueryType.prepend(DecidimCfjApiUserQueryPatch)
end
