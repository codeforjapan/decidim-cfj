# frozen_string_literal: true

module Decidim
  module Comments
    # A command with all the business logic to destroy a comment
    class DestroyAllComments < Rectify::Command
      # Public: Initializes the command.
      #
      # organization - The organization to destroy all comments.
      def initialize(organization)
        @organization = organization
      end

      # Executes the command. Broadcasts these events:
      #
      # - :ok when everything is valid.
      #
      # Returns nothing.
      def call
        Decidim::Comments::Comment.find_each do |comment|
          if comment.organization == organization
            puts "destroy comment id: #{comment.id}, for #{comment.decidim_root_commentable_type}:#{comment.decidim_root_commentable_id}"
            comment.destroy!
          end
        end

        broadcast(:ok)
      end

      private

      attr_reader :organization
    end
  end
end
