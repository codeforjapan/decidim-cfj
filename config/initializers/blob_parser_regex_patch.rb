# frozen_string_literal: true

# Back-port of Decidim::ContentParsers::BlobParser from decidim-core v0.30.9
# onto cfj's current v0.29.x install.
#
# The v0.29.x upstream regex defines the URL host part as `((?!/rails).)+`,
# a greedy negative-lookahead that consumes any character — including HTML
# tags, quotes, and angle brackets — until it reaches `/rails`. When a body
# field contains both an external <img src="..."> and an ActiveStorage blob
# <img src="..."> later on, the regex matches one span starting at the
# external URL host and ending at the blob URL's filename. `gsub` then
# replaces that entire span with a single Global ID, destroying the
# external img tag, the wrapper opening tag, and the blob img's leading
# `<img src=`. v0.30.x fixed this by switching the host part to
# URI::DEFAULT_PARSER.make_regexp(%w(https http)) and adopting named
# captures throughout. The two changes are paired (regex shape + named
# capture access in replace_blobs), so we ship them together.
#
# This patch coexists with `blob_parser_override.rb` (S3 URL extension),
# which aliases `rewrite` and calls `original_rewrite` — the original
# `rewrite` then calls our prepended `replace_blobs`.
#
# TODO: remove this file once cfj upgrades to decidim-core v0.30.x.

module Decidim
  module ContentParsers
    # Mirrors the BlobParser#replace_blobs implementation shipped in
    # decidim-core v0.30.9. Prepended so its named-capture access matches
    # the BLOB_REGEX shape installed alongside it below.
    module BlobParserUpstreamFix
      private

      def replace_blobs(text)
        text.gsub(self.class::BLOB_REGEX) do |match|
          named_captures = Regexp.last_match.named_captures

          type_part = named_captures["type_part"]
          key_part = named_captures["key_part"]

          variation_key = nil
          blob =
            if type_part == "disk"
              decoded = ActiveStorage.verifier.verified(key_part, purpose: :blob_key)
              ActiveStorage::Blob.find_by(key: decoded[:key]) if decoded
            else
              if type_part.start_with?("representations")
                variation_part = named_captures["variation_part"]
                variation_key = generate_variation_key(variation_part)
              end

              ActiveStorage::Blob.find_signed(key_part)
            end
          next match unless blob

          "#{blob.to_global_id}#{"/#{variation_key}" if variation_key}"
        end
      end
    end
  end
end

Rails.application.config.to_prepare do
  Decidim::ContentParsers::BlobParser.send(:remove_const, :BLOB_REGEX) if
    Decidim::ContentParsers::BlobParser.const_defined?(:BLOB_REGEX, false)

  Decidim::ContentParsers::BlobParser.const_set(
    :BLOB_REGEX,
    %r{
      (?<host_part>
        #{URI::DEFAULT_PARSER.make_regexp(%w(https http))}
      )?
      /rails/active_storage
      /(?<type_part>blobs/redirect|blobs/proxy|blobs|representations/redirect|representations/proxy|representations|disk)
      /(?<key_part>[^/]+)
      (
        /(?<variation_part>[\w.=-]+)
      )?
      /((?:[^\s/"<>']|'(?=[^\s/"<>']))+)
    }x
  )

  unless Decidim::ContentParsers::BlobParser.include?(Decidim::ContentParsers::BlobParserUpstreamFix)
    Decidim::ContentParsers::BlobParser.prepend(Decidim::ContentParsers::BlobParserUpstreamFix)
  end
end
