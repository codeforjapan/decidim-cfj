# frozen_string_literal: true

module Decidim
  module Organizations
    # A command with all the business logic when destroys organization.
    class DestroyOrganization < Decidim::Command
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

        Decidim::Verifications::CsvDatum.where(organization:).delete_all

        Decidim::Verifications::Conflict.find_each do |conflict|
          if conflict.current_user.organization == organization || conflict.managed_user.organization == organization
            puts "destroy verifications_conflict id: #{conflict.id}"
            conflict.destroy!
          end
        end

        Decidim::TermCustomizer::Constraint.where(organization:).delete_all

        Decidim::EditorImage.where(organization:).delete_all

        Decidim::DecidimAwesome::EditorImage.where(organization:).delete_all

        Decidim::ActionLog.where(organization:).delete_all

        Decidim::AssembliesSetting.where(organization:).delete_all

        organization.destroy!

        broadcast(:ok)
      end

      private

      attr_reader :organization
    end
  end
end
