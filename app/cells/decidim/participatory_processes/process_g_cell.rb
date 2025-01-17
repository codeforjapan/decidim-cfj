# frozen_string_literal: true

module Decidim
  module ParticipatoryProcesses
    # This cell renders the Grid (:g) process card
    # for a given instance of a ParticipatoryProcess
    class ProcessGCell < Decidim::CardGCell
      private

      def resource_path
        Decidim::ParticipatoryProcesses::Engine.routes.url_helpers.participatory_process_path(model)
      end

      def resource_image_url
        if model.respond_to?(:hero_image) && model.hero_image.attached?
          return rails_blob_path(model.hero_image, only_path: false)
        end

        nil
      end

      def start_date
        model.start_date
      end

      def end_date
        model.end_date
      end

      def metadata_cell
        "decidim/participatory_processes/process_metadata_g"
      end
    end
  end
end
