# frozen_string_literal: true

module Decidim
  module ParticipatoryProcesses
    # A command with all the business logic when destroys all participatory_processes.
    class DestroyAllParticipatoryProcesses < Decidim::Command
      # Public: Initializes the command.
      #
      # organization - The organization to destroy all participatory_processes.
      def initialize(organization)
        @organization = organization
      end

      # Executes the command. Broadcasts these events:
      #
      # - :ok when everything is valid and the participatory_process is deleted.
      #
      # Returns nothing.
      def call
        Decidim::ParticipatoryProcess.where(organization: organization).find_each do |participatory_process|
          puts "destroy participatory_process id: #{participatory_process.id}"
          participatory_process.destroy!
        end
        Decidim::ParticipatoryProcessGroup.where(organization: organization).find_each do |participatory_process_group|
          puts "destroy participatory_process_group id: #{participatory_process_group.id}"
          participatory_process_group.destroy!
        end
        Decidim::ParticipatoryProcessType.where(organization: organization).destroy_all
        Decidim::NavigationMaps::Blueprint.where(organization: organization).destroy_all
        Decidim::ContentBlock.where(organization: organization).destroy_all
        Decidim::Scope.where(organization: organization).destroy_all
        Decidim::ScopeType.where(organization: organization).destroy_all
        Decidim::StaticPage.where(organization: organization).delete_all ## some static_pages are not removed by `destroy_all`
        Decidim::StaticPageTopic.where(organization: organization).destroy_all
        Decidim::SearchableResource.where(organization: organization).destroy_all
        Decidim::ContextualHelpSection.where(organization: organization).destroy_all

        broadcast(:ok)
      end

      private

      attr_reader :organization
    end
  end
end
