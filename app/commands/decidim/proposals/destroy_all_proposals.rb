# frozen_string_literal: true

module Decidim
  module Proposals
    # A command with all the business logic when destroys all proposals.
    class DestroyAllProposals < Rectify::Command
      # Public: Initializes the command.
      #
      # organization - The organization to destroy all proposals.
      def initialize(organization)
        @organization = organization
      end

      # Executes the command. Broadcasts these events:
      #
      # - :ok when everything is valid and the proposal is deleted.
      #
      # Returns nothing.
      def call
        Decidim::Proposals::Proposal.find_each do |proposal|
          if proposal.organization == organization
            proposal.amendments.each do |amendment|
              puts "destroy amendment id: #{amendment.id}"
              amendment.destroy!
            end
            puts "destroy proposal id: #{proposal.id}, for component id: #{proposal.decidim_component_id}"
            proposal.destroy!
          end
        end

        Decidim::Proposals::CollaborativeDraft.find_each do |draft|
          if draft.organization == organization
            puts "destroy collaborative draft id: #{draft.id}, for component id: #{draft.decidim_component_id}"
            draft.destroy!
          end
        end

        broadcast(:ok)
      end

      private

      attr_reader :organization
    end
  end
end
