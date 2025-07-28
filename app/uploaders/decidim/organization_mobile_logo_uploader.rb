# frozen_string_literal: true

module Decidim
  class OrganizationMobileLogoUploader < ImageUploader
    set_variants do
      { medium: { resize_to_fit: [360, 120] } }
    end
  end
end
