# frozen_string_literal: true

module Decidim
  module ContentParsers
    # Override of InlineImagesParser to use Global IDs instead of signed URLs
    # This prevents images from disappearing when signed URLs expire
    class InlineImagesParser < BaseParser
      # @return [String] the content with the inline images replaced.
      def rewrite
        return content unless inline_images?

        replace_inline_images
        parsed_content.to_html
      end

      def inline_images?
        parsed_content.search(:img).find do |image|
          image.attr(:src)&.match?(%r{\Adata:image/[a-z]{3,4};base64,})
        end
      end

      private

      def parsed_content
        @parsed_content ||= Nokogiri::HTML(content)
      end

      def replace_inline_images
        parsed_content.search(:img).each do |image|
          src = image.attr(:src)
          next unless src&.match?(%r{\Adata:image/[a-z]{3,4};base64,})

          file = base64_tempfile(src)
          editor_image = EditorImage.create!(
            decidim_author_id: context[:user]&.id,
            organization: context[:user]&.organization,
            file:
          )

          # Use Global ID instead of signed URL to prevent expiration
          image.set_attribute(:src, editor_image.file.blob.to_global_id.to_s)
        end
      end

      def base64_tempfile(base64_data, filename = nil)
        return nil unless base64_data.is_a?(String)

        start_regex = %r{\Adata:image/[a-z]{3,4};base64,}
        filename ||= SecureRandom.hex

        regex_result = start_regex.match(base64_data)
        return nil unless regex_result

        start = regex_result.to_s
        tempfile = Tempfile.new(filename)
        tempfile.binmode
        tempfile.write(Base64.decode64(base64_data[start.length..-1]))
        ActionDispatch::Http::UploadedFile.new(
          tempfile:,
          filename:,
          original_filename: filename
        )
      end
    end
  end
end
