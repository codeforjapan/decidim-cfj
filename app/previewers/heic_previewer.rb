class HeicPreviewer < ActiveStorage::Previewer
  CONTENT_TYPE = "image/heic"

  class << self
    def accept?(blob)
      blob.content_type == CONTENT_TYPE && minimagick_exists?
    end

    def minimagick_exists?
      return @minimagick_exists unless @minimagick_exists.blank?

      @minimagick_exists = defined?(ImageProcessing::MiniMagick)
      Rails.logger.error "#{self.class} :: MiniMagick is not installed" unless @minimagick_exists

      @minimagick_exists
    end
  end

  def preview(transformations)
    download_blob_to_tempfile do |input|
      io = ImageProcessing::MiniMagick.source(input).convert("png").call
      yield io: io, filename: "#{blob.filename.base}.png", content_type: "image/png"
    end
  end
end
