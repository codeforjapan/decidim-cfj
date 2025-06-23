# frozen_string_literal: true

# Override Decidim's uploader to return Global IDs instead of signed URLs
# This prevents signed S3 URLs from being used in rich text editors

Rails.application.config.to_prepare do
  # Skip this override in test environments to avoid method conflicts
  next if Rails.env.test?

  # Override EditorImage to use Global IDs
  if defined?(Decidim::EditorImage)
    Decidim::EditorImage.class_eval do
      include GlobalID::Identification

      # Only override if not already done
      unless method_defined?(:original_attached_uploader)
        # Store original method
        alias_method :original_attached_uploader, :attached_uploader

        # Override the attached_uploader method to return a Global ID aware uploader
        def attached_uploader(column)
          @global_id_uploaders ||= {}
          @global_id_uploaders[column] ||= GlobalIdUploader.new(self, column)
        end
      end
    end

    # Custom uploader that returns Global IDs for path method
    class GlobalIdUploader < SimpleDelegator
      def initialize(model, column)
        @model = model
        @column = column
        # Use the original attached_uploader method
        original_uploader = @model.original_attached_uploader(column)
        super(original_uploader)
      end

      # Override path to return Global ID
      def path
        blob = @model.send(@column)&.blob
        return blob.to_global_id.to_s if blob

        # Fallback to original path if no blob
        super
      end
    end
  end
end
