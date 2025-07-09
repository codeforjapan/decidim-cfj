# frozen_string_literal: true

module Decidim
  # This class deals with uploading hero images to ParticipatoryProcesses.
  class ImageUploader < ApplicationUploader
    def validable_dimensions
      true
    end

    def content_type_allowlist
      extension_allowlist.filter_map do |ext|
        mime_type = MiniMime.lookup_by_extension(ext)
        if mime_type
          mime_type.content_type
        else
          Rails.logger.warn "Unknown file extension: #{ext}"
          nil
        end
      end.uniq
    end

    # Fetches info about different variants, their processors and dimensions
    def dimensions_info
      return if variants.blank?

      variants.transform_values do |variant|
        {
          processor: variant.keys.first,
          dimensions: variant.values.first
        }
      end
    end

    # Add a white list of extensions which are allowed to be uploaded.
    # For images you might use something like this:
    def extension_allowlist
      Decidim.organization_settings(model).upload_allowed_file_extensions_image
    end

    def max_image_height_or_width
      8000
    end

    private

    def maximum_upload_size
      Decidim.organization_settings(model).upload_maximum_file_size
    end
  end
end
