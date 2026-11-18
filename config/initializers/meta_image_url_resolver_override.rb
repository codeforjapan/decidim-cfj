# frozen_string_literal: true

# Looks up a blob by ID only for the GlobalIDs that the editor stores. The last
# URL segment was looked up as an ID, so a file name such as "7ba662.jpg" was
# cast to ID 7 and picked an unrelated blob as the meta image.
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

    def find_blob_by_id(_blob_id)
      nil
    end

    # The GlobalID may be followed by a variation key, which
    # GlobalID::Locator does not resolve.
    def find_blob_from_url(url)
      blob_id = url[%r{\Agid://[^/]+/ActiveStorage::Blob/(\d+)(?:/|\z)}, 1]
      return ActiveStorage::Blob.find_by(id: blob_id) if blob_id

      super
    end
  end

  Decidim::MetaImageUrlResolver.prepend(DecidimMetaImageUrlResolverBlobIdPatch)
end
