# frozen_string_literal: true

module Decidim
  # The code entered on the admin login code page.
  class AdminLoginCodeForm < Form
    attribute :code, String

    validates :code, presence: true, format: { with: /\A\d{#{Decidim::AdminLoginCode::CODE_LENGTH}}\z/o }

    def code
      super&.strip
    end
  end
end
