# frozen_string_literal: true

module Decidim
  # This class deals with uploading files to Decidim. It is intended to just
  # hold the uploads configuration, so you should inherit from this class and
  # then tweak any configuration you need.
  class ApplicationUploader < CarrierWave::Uploader::Base
    process :validate_inside_organization

    # Override the directory where uploaded files will be stored.
    # This is a sensible default for uploaders that are meant to be mounted:
    def store_dir
      default_path = "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"

      return File.join(Decidim.base_uploads_path, default_path) if Decidim.base_uploads_path.present?

      default_path
    end

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

    protected

    # Validates that the associated model is always within an organization in
    # order to pass the organization specific settings for the file upload
    # checks (e.g. file extension, mime type, etc.).
    def validate_inside_organization
      return if model.is_a?(Decidim::Organization)
      return if model.respond_to?(:organization) && model.organization.is_a?(Decidim::Organization)

      # HACK: Temporary fix for https://github.com/decidim/decidim/issues/6720
      # If this is fixed by decidim, this file (application_uploader.rb)
      # should be deleted to keep in sync with upstream!
      return if model.class.to_s == "decidim/hero_homepage_content_block"
      #      Fix for https://github.com/codeforjapan/decidim-cfj/issues/101
      return if model.nil?

      raise CarrierWave::IntegrityError, I18n.t("carrierwave.errors.not_inside_organization")
    end
  end
end
