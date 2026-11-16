# frozen_string_literal: true

# Looks up a blob by ID only when the last URL segment is an integer. Otherwise
# a file name such as "7ba662.jpg" is cast to ID 7 and picks an unrelated blob
# as the meta image.
#
# Also skips blobs that cannot be resized, such as a PDF, which raised while
# rendering the whole page.
Rails.application.config.to_prepare do
  module DecidimMetaImageUrlResolverBlobIdPatch
    def resolve
      return unless blob&.variable?

      super
    end

    private

    def find_blob_by_id(blob_id)
      return unless blob_id.to_s.match?(/\A\d+\z/)

      super
    end
  end

  Decidim::MetaImageUrlResolver.prepend(DecidimMetaImageUrlResolverBlobIdPatch)
end
