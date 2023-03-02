# frozen_string_literal: true

module Decidim
  module Areas
    # A command with all the business logic when destroys all areas.
    class DestroyAllAreas < Rectify::Command
      # Public: Initializes the command.
      #
      # organization - The organization to destroy all areas.
      def initialize(organization)
        @organization = organization
      end

      # Executes the command. Broadcasts these events:
      #
      # - :ok when everything is valid and the area is deleted.
      #
      # Returns nothing.
      def call
        Decidim::Area.find_each do |area|
          if area.organization == organization
            puts "destroy area id: #{area.id}"
            area.destroy!
          end
        end

        Decidim::AreaType.find_each do |area_type|
          if area_type.organization == organization
            puts "destroy area_type id: #{area_type.id}"
            area_type.destroy!
          end
        end

        broadcast(:ok)
      end

      private

      attr_reader :organization
    end
  end
end
