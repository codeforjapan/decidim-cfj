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

      # 上流は attached_uploader(:hero_image).url を使うが、これは署名付きの S3 URL を
      # 直接返す(失効する・バケット名が露出する・CloudFront を迂回する)。cfj は
      # production.rb の resolve_model_to_route = :rails_storage_proxy に合わせて
      # プロキシ経由のパスを使う。
      #
      # ここで Rails.application.routes を明示するのが要点。ビューの rails_blob_path は
      # コンポーネントのエンジン配下で描画されると SCRIPT_NAME
      # (/ja/processes/:slug/f/:id) が前置され、/ja/processes/…/rails/active_storage/…
      # という壊れた URL になる。トップページでは SCRIPT_NAME が空なので表面化しない。
      def resource_image_url
        return unless model.respond_to?(:hero_image) && model.hero_image.attached?

        Rails.application.routes.url_helpers.rails_blob_path(model.hero_image, only_path: true)
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
