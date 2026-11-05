# frozen_string_literal: true

# Override Decidim::ApplicationUploader#remote_url= so the import flows
# (assemblies, accountability, etc.) fetch remote attachments through a
# controlled HTTP client instead of `URI.open`.
#
# AvatarFetcher is reused as a generic remote-file fetcher with the content-type
# whitelist disabled. A failed fetch raises SocketError to keep the contract
# expected by callers like Decidim::Assemblies::AssemblyImporter, whose
# `rescue` list converts network-level failures into per-attachment warnings
# rather than aborting the whole import.
Rails.application.config.to_prepare do
  Decidim::ApplicationUploader # rubocop:disable Lint/Void

  module DecidimApplicationUploaderRemoteUrlPatch
    def remote_url=(url)
      io, filename = Decidim::UserExtension::AvatarFetcher.call(
        url,
        allowed_content_types: nil,
        default_filename: "remote_file"
      )
      raise SocketError, "remote_url= fetch failed" unless io

      model.send(mounted_as).attach(io:, filename:)
    end
  end

  Decidim::ApplicationUploader.prepend(DecidimApplicationUploaderRemoteUrlPatch)
end
