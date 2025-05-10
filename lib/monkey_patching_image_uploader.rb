# frozen_string_literal: true

# To fix a value of `Decidim::ImageUploader#max_image_height_or_width`
module ImageUploaderMaxSizeOverride
  def max_image_height_or_width
    8000
  end
end

Decidim::ImageUploader.prepend(ImageUploaderMaxSizeOverride)

# To override `Decidim::Cw::ApplicationUploader#url`
module ApplicationUploaderUrlOverride
  # Overwrite: If the content block is in preview mode, then we show the
  # URL using the asset_host domain
  def url(*args)
    if path.nil?
      default_url(*args)
    else
      encoded_path = encode_path(path.sub(File.expand_path(root), ""))
      if (host = asset_host)
        if host.respond_to? :call
          "#{host.call(self)}/#{encoded_path}"
        else
          "#{host}/#{encoded_path}"
        end
      else
        (base_path || "") + encoded_path
      end
    end
  end
end

Decidim::Cw::ApplicationUploader.prepend(ApplicationUploaderUrlOverride)
