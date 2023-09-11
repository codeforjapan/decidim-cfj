# frozen_string_literal: true

module Decidim
  module Debates
    # A command with all the business logic when destroys all debates.
    class DestroyAllDebates < Decidim::Command
      # Public: Initializes the command.
      #
      # organization - The organization to destroy all debates.
      def initialize(organization)
        @organization = organization
      end

      # Executes the command. Broadcasts these events:
      #
      # - :ok when everything is valid and the debate is deleted.
      #
      # Returns nothing.
      def call
        Decidim::Debates::Debate.find_each do |debate|
          if debate.organization == organization
            puts "destroy debate id: #{debate.id}, for component id: #{debate.decidim_component_id}"
            debate.destroy!
          end
        end

        broadcast(:ok)
      end

      private

      attr_reader :organization
    end
  end
end
