# frozen_string_literal: true

module Decidim
  class OrganizationMobileLogoUploader < ImageUploader
    set_variants do
      {
        small: { resize_to_fit: [180, 60] },
        medium: { resize_to_fit: [360, 120] }
      }
    end

    def dimensions_info
      {
        small: { processor: :resize_to_fit, dimensions: [180, 60] },
        medium: { processor: :resize_to_fit, dimensions: [360, 120] }
      }
    end
  end
end
