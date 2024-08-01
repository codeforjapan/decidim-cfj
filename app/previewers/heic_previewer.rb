# frozen_string_literal: true

class HeicPreviewer < ActiveStorage::Previewer
  CONTENT_TYPES = %w(image/heic image/heif image/heic-sequence image/heif-sequence).freeze

  class << self
    def accept?(blob)
      CONTENT_TYPES.include?(blob.content_type) && minimagick_exists?
    end

    def minimagick_exists?
      return @minimagick_exists if @minimagick_exists.present?

      @minimagick_exists = defined?(ImageProcessing::MiniMagick)
      Rails.logger.error "#{self.class} :: MiniMagick is not installed" unless @minimagick_exists

      @minimagick_exists
    end
  end

  def preview(**_options)
    download_blob_to_tempfile do |input|
      begin
        io = ImageProcessing::MiniMagick.source(input).convert("png").call
      rescue ImageProcessing::Error
        io = ImageProcessing::MiniMagick.loader(page: 0).source(input).convert("png").call
      end
      yield io:, filename: "#{blob.filename.base}.png", content_type: "image/png"
    end
  end
end
