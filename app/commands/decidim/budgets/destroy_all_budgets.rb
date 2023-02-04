# frozen_string_literal: true

module Decidim
  module Budgets
    # A command with all the business logic when destroys all budgets.
    class DestroyAllBudgets < Rectify::Command
      # Public: Initializes the command.
      #
      # organization - The organization to destroy all budgets.
      def initialize(organization)
        @organization = organization
      end

      # Executes the command. Broadcasts these events:
      #
      # - :ok when everything is valid and the budget is deleted.
      #
      # Returns nothing.
      def call
        Decidim::Budgets::Budget.find_each do |budget|
          if budget.organization == organization
            puts "destroy budget id: #{budget.id}, for component id: #{budget.decidim_component_id}"
            budget.destroy!
          end
        end

        broadcast(:ok)
      end

      private

      attr_reader :organization
    end
  end
end
