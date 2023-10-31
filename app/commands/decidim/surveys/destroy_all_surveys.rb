# frozen_string_literal: true

module Decidim
  module Surveys
    # A command with all the business logic when destroys all surveys.
    class DestroyAllSurveys < Decidim::Command
      # Public: Initializes the command.
      #
      # organization - The organization to destroy all surveys.
      def initialize(organization)
        @organization = organization
      end

      # Executes the command. Broadcasts these events:
      #
      # - :ok when everything is valid and the survey is deleted.
      #
      # Returns nothing.
      def call
        Decidim::Surveys::Survey.find_each do |survey|
          if survey.organization == organization
            puts "destroy survey id: #{survey.id}, for component id: #{survey.decidim_component_id}"
            survey.destroy!
          end
        end

        broadcast(:ok)
      end

      private

      attr_reader :organization
    end
  end
end
