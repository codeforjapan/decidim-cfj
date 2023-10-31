# frozen_string_literal: true

module Decidim
  # A command with all the business logic when destroys all proposals.
  class DestroyAllAttachments < Decidim::Command
    # Public: Initializes the command.
    #
    # organization - The organization to destroy all results.
    def initialize(organization)
      @organization = organization
    end

    # Executes the command. Broadcasts these events:
    #
    # - :ok when everything is valid and the results and statsues is deleted.
    #
    # Returns nothing.
    def call
      Decidim::Attachment.find_each do |attachment|
        if attachment.organization == organization
          puts "destroy attachment id: #{attachment.id}, for #{attachment.attached_to_type}:#{attachment.attached_to_id}"
          attachment.file.purge
          attachment.destroy!
        end
      end

      broadcast(:ok)
    end

    private

    attr_reader :organization
  end
end
