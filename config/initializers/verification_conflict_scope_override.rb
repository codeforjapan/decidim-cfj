# frozen_string_literal: true

# Scopes the authorization looked up when registering a verification conflict to
# the organization of the user being authorized.
#
# The sibling lookups in this area are already organization-scoped
# (AuthorizationHandler#duplicate and
# Admin::ImpersonationsController#existing_managed_user); this one is not, and
# unique_id carries no organization component, so it can otherwise resolve an
# authorization belonging to a different organization.
#
# The method body mirrors the upstream one apart from the scope, since the
# lookup is inline and there is no narrower seam to override.
Rails.application.config.to_prepare do
  Decidim::Verifications::AuthorizeUser # rubocop:disable Lint/Void

  module DecidimVerificationsConflictScopePatch
    private

    def create_verification_conflict
      return if handler.user.blank?

      authorization = Decidim::Authorization.find_by(
        user: Decidim::User.where(organization: handler.user.organization),
        unique_id: handler.unique_id
      )
      return if authorization.blank?

      conflict = Decidim::Verifications::Conflict.find_or_initialize_by(
        current_user: handler.user,
        managed_user: authorization.user,
        unique_id: handler.unique_id
      )

      conflict.update(times: conflict.times + 1)

      conflict
    end
  end

  Decidim::Verifications::AuthorizeUser.prepend(DecidimVerificationsConflictScopePatch)
end
