# frozen_string_literal: true

require "base64"
require "json"

module Decidim
  module Cfj
    # Resolves the blob behind an Active Storage URL's signed token even when
    # that token's expiry has passed.
    #
    # Active Storage's own lookups (Blob.find_signed, verifier.verified) refuse
    # expired tokens, which is right when serving a file but wrong when all we
    # want is to identify which blob a URL in saved content refers to. Only the
    # expiry is disregarded here: the signature is still verified, so a forged
    # token cannot point content at an arbitrary blob (blob ids are sequential,
    # so that would otherwise expose other organizations' files).
    #
    # This is the only place that knows how Active Storage encodes its tokens.
    class SignedBlobToken
      # Which signing purpose each Active Storage URL type uses. The type comes
      # from the capture of the same name in BlobParser::BLOB_REGEX.
      PURPOSES = {
        "disk" => :blob_key,
        "blobs" => :blob_id,
        "blobs/redirect" => :blob_id,
        "blobs/proxy" => :blob_id,
        "representations" => :blob_id,
        "representations/redirect" => :blob_id,
        "representations/proxy" => :blob_id
      }.freeze

      class << self
        # @param type_part [String] URL type, e.g. "blobs/redirect" or "disk"
        # @param token [String] signed id (blobs/*) or encoded key (disk)
        # @return [ActiveStorage::Blob, nil]
        def blob_for(type_part, token)
          purpose = PURPOSES[type_part]
          return nil unless purpose

          payload = verified_payload(token, purpose)
          return nil if payload.blank?

          case purpose
          when :blob_id then ActiveStorage::Blob.find_by(id: payload)
          when :blob_key then ActiveStorage::Blob.find_by(key: payload[:key])
          end
        end

        private

        # Mirrors ActiveSupport::MessageVerifier#verified, minus the expiry
        # check in Messages::Metadata: verify the HMAC, then unwrap the metadata
        # envelope. Marshal is the verifier's default serializer, and the
        # payload has been authenticated before it is loaded.
        #
        # The envelope format is internal to Rails, so this degrades to "leave
        # the URL alone" - the behaviour before this existed - rather than
        # raising, if a future Rails changes it.
        def verified_payload(token, purpose)
          return nil unless token.is_a?(String) && ActiveStorage.verifier.valid_message?(token)

          # urlsafe_decode64 also accepts standard Base64, so this keeps working
          # whichever encoding Active Storage signs its tokens with.
          envelope = JSON.parse(Base64.urlsafe_decode64(token.split("--").first))
          metadata = envelope["_rails"]
          return nil unless metadata && metadata["pur"] == purpose.to_s

          Marshal.load(Base64.urlsafe_decode64(metadata["message"])) # rubocop:disable Security/MarshalLoad
        rescue StandardError => e
          # Deliberately broad: this runs on every rich text save, so an
          # unexpected encoding must not take the save down with it.
          Rails.logger.warn "Failed to read Active Storage token for #{purpose}: #{e.message}"
          nil
        end
      end
    end
  end
end
