# frozen_string_literal: true

# Resolves the OAuth client of an authorization request among the applications
# of the current organization, and answers /oauth/me only for tokens issued to
# an application of the current organization.
Rails.application.config.to_prepare do
  Decidim::Doorkeeper::AuthorizationsController # rubocop:disable Lint/Void
  Decidim::Doorkeeper::CredentialsController # rubocop:disable Lint/Void

  module DecidimDoorkeeperAuthorizationsOrganizationPatch
    def self.prepended(base)
      base.before_action :set_oauth_application
    end

    def oauth_application
      @oauth_application
    end

    private

    def set_oauth_application
      return if params[:client_id].blank?

      @oauth_application = current_organization.oauth_applications.find_by!(uid: params[:client_id])
    end
  end

  module DecidimDoorkeeperCredentialsOrganizationPatch
    def self.prepended(base)
      base.before_action :ensure_token_application_in_organization
    end

    private

    def ensure_token_application_in_organization
      return if doorkeeper_token&.application&.decidim_organization_id == current_organization.id

      head :unauthorized
    end

    def current_resource_owner
      @current_resource_owner ||= current_organization.users.find(doorkeeper_token.resource_owner_id) if doorkeeper_token
    end
  end

  Decidim::Doorkeeper::AuthorizationsController.prepend(DecidimDoorkeeperAuthorizationsOrganizationPatch)
  Decidim::Doorkeeper::CredentialsController.prepend(DecidimDoorkeeperCredentialsOrganizationPatch)
end
