# frozen_string_literal: true

module Decidim
  module Pages
    # A command with all the business logic when destroys all pages.
    class DestroyAllPages < Rectify::Command
      # Public: Initializes the command.
      #
      # organization - The organization to destroy all pages.
      def initialize(organization)
        @organization = organization
      end

      # Executes the command. Broadcasts these events:
      #
      # - :ok when everything is valid and the page is deleted.
      #
      # Returns nothing.
      def call
        Decidim::Pages::Page.find_each do |page|
          if page.organization == organization
            puts "destroy page id: #{page.id}, for component id: #{page.decidim_component_id}"
            page.destroy!
          end
        end

        broadcast(:ok)
      end

      private

      attr_reader :organization
    end
  end
end
