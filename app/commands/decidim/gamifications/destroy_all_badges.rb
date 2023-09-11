# frozen_string_literal: true

module Decidim
  module Gamifications
    # A command with all the business logic when destroys all meetings.
    class DestroyAllBadges < Decidim::Command
      # Public: Initializes the command.
      #
      # organization - The organization to destroy all meetings.
      def initialize(organization, user)
        @organization = organization
        @user = user
      end

      # Executes the command. Broadcasts these events:
      #
      # - :ok when everything is valid and the meeting is deleted.
      #
      # Returns nothing.
      def call
        if user.organization == organization
          Decidim::Gamification::BadgeScore.where(user: user).find_each do |badge_score|
            puts "destroy badge_score id: #{badge_score.id}, badge_name: #{badge_score.badge_name}"
            badge_score.destroy!
          end
        end

        broadcast(:ok)
      end

      private

      attr_reader :organization, :user
    end
  end
end
