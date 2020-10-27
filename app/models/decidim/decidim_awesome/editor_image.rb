# frozen_string_literal: true

module Decidim
  module DecidimAwesome
    class EditorImage < ApplicationRecord
      self.table_name = "decidim_awesome_editor_images"

      belongs_to :author, foreign_key: :decidim_author_id, class_name: "Decidim::User"
      belongs_to :organization, foreign_key: :decidim_organization_id, class_name: "Decidim::Organization"

      validates :organization, presence: true
      validates :author, presence: true

      # HACK: Temporary fix making Decidim.maximum_attachment_size ->
      #       Decidim.config.maximum_attachment_size
      #       for newer decidim versions
      # If this is fixed in decidim-awesome, this file (editor_image.rb)
      # should be deleted to keep in sync with upstream!

      validates :image,
                file_size: { less_than_or_equal_to: ->(_record) { Decidim.config.maximum_attachment_size } },
                file_content_type: { allow: ["image/jpeg", "image/png"] }

      mount_uploader :image, Decidim::DecidimAwesome::ImageUploader

      delegate :url, to: :image
      delegate :thumbnail, to: :image
    end
  end
end
