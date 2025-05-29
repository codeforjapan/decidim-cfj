# frozen_string_literal: true

module Decidim
  module Assemblies
    # A command with all the business logic when destroys all assemblies.
    class DestroyAllAssemblies < Decidim::Command
      # Public: Initializes the command.
      #
      # organization - The organization to destroy all assemblies.
      def initialize(organization)
        @organization = organization
      end

      # Executes the command. Broadcasts these events:
      #
      # - :ok when everything is valid and the assembly is deleted.
      #
      # Returns nothing.
      def call
        Decidim::Assembly.where(organization:).find_each do |assembly|
          puts "destroy assembly id: #{assembly.id}"
          assembly.destroy!
        end
        Decidim::AssembliesType.where(organization:).destroy_all

        broadcast(:ok)
      end

      private

      attr_reader :organization
    end
  end
end
