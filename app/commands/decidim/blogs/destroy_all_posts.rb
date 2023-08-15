# frozen_string_literal: true

module Decidim
  module Blogs
    # A command with all the business logic when destroys all posts.
    class DestroyAllPosts < Decidim::Command
      # Public: Initializes the command.
      #
      # organization - The organization to destroy all posts.
      def initialize(organization)
        @organization = organization
      end

      # Executes the command. Broadcasts these events:
      #
      # - :ok when everything is valid and the post is deleted.
      #
      # Returns nothing.
      def call
        Decidim::Blogs::Post.find_each do |post|
          if post.organization == organization
            puts "destroy post id: #{post.id}, for component id: #{post.decidim_component_id}"
            post.destroy!
          end
        end

        broadcast(:ok)
      end

      private

      attr_reader :organization
    end
  end
end
