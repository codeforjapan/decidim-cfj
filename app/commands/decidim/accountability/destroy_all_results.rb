# frozen_string_literal: true

module Decidim
  module Accountability
    # A command with all the business logic when destroys all proposals.
    class DestroyAllResults < Decidim::Command
      # Public: Initializes the command.
      #
      # organization - The organization to destroy all results.
      def initialize(organization)
        @organization = organization
      end

      # Executes the command. Broadcasts these events:
      #
      # - :ok when everything is valid and the results and statsues is deleted.
      #
      # Returns nothing.
      def call
        Decidim::Accountability::Result.find_each do |result|
          if result&.organization == organization
            puts "destroy result id: #{result.id}, for component id: #{result.decidim_component_id}"
            result.destroy!
          end
        end

        Decidim::Accountability::Status.find_each do |status|
          if status.organization == organization
            puts "destroy status id: #{status.id}, for component id: #{status.decidim_component_id}"
            status.destroy!
          end
        end

        broadcast(:ok)
      end

      private

      attr_reader :organization
    end
  end
end
