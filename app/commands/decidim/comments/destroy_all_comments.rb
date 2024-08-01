# frozen_string_literal: true

module Decidim
  module Comments
    # A command with all the business logic to destroy a comment
    class DestroyAllComments < Decidim::Command
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
        begin
          deletable_ids = []
          Decidim::Comments::Comment.find_each(batch_size: 100) do |comment|
            if comment&.organization == organization # rubocop:disable Style/IfUnlessModifier
              deletable_ids << comment.id
            end
          rescue Module::DelegationError
            # If commentable of comment is nil, the comment should be removed
            deletable_ids << comment.id
          end

          deletable_ids.reverse.each_slice(30) do |ids|
            Decidim::Comments::Comment.where(id: ids).order(id: :desc).each do |comment|
              puts "destroy comment id: #{comment.id}, for #{comment.decidim_root_commentable_type}:#{comment.decidim_root_commentable_id}"
              # force to delete (ignore validation)
              Decidim::Comments::CommentVote.where(comment:).delete_all
              comment.delete
            end
          end
        rescue Exception => e # rubocop:disable Lint/RescueException
          pp "error?: #{e.inspect}"
        end

        broadcast(:ok)
      end

      private

      attr_reader :organization
    end
  end
end
