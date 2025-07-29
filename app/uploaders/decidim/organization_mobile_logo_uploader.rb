# frozen_string_literal: true

module Decidim
  class OrganizationMobileLogoUploader < RecordImageUploader
    set_variants do
      { medium: { resize_to_fit: [360, 100] } }
    end
  end
end
