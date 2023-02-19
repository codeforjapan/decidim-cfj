# frozen_string_literal: true

module Decidim
  module Organizations
    # A command with all the business logic when destroys organization.
    class DestroyOrganization < Rectify::Command
      # Public: Initializes the command.
      #
      # organization - The organization to destroy.
      def initialize(organization)
        @organization = organization
      end

      # Executes the command. Broadcasts these events:
      #
      # - :ok when everything is valid and the organization is deleted.
      #
      # Returns nothing.
      def call
        Decidim::DecidimAwesome::AwesomeConfig.find_each do |awesome_config|
          if awesome_config.organization == organization
            puts "destroy awesome_config id: #{awesome_config.id}"
            awesome_config.destroy!
          end
        end

        Decidim::DecidimAwesome::EditorImage.where(organization: organization).delete_all

        Decidim::ActionLog.where(organization: organization).delete_all

        Decidim::AssembliesSetting.where(organization: organization).delete_all

        organization.destroy!

        broadcast(:ok)
      end

      private

      attr_reader :organization
    end
  end
end
