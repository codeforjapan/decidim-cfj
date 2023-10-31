# frozen_string_literal: true

module Decidim
  module Meetings
    # A command with all the business logic when destroys all meetings.
    class DestroyAllMeetings < Decidim::Command
      # Public: Initializes the command.
      #
      # organization - The organization to destroy all meetings.
      def initialize(organization)
        @organization = organization
      end

      # Executes the command. Broadcasts these events:
      #
      # - :ok when everything is valid and the meeting is deleted.
      #
      # Returns nothing.
      def call
        Decidim::Meetings::Meeting.find_each do |meeting|
          if meeting.organization == organization
            puts "destroy meeting id: #{meeting.id}, for component id: #{meeting.decidim_component_id}"
            meeting.destroy!
          end
        end

        broadcast(:ok)
      end

      private

      attr_reader :organization
    end
  end
end
