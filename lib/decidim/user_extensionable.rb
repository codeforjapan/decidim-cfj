# frozen_string_literal: true

require "active_support/concern"

module Decidim
  # This concern contains the logic related to user extension.
  module UserExtensionable
    extend ActiveSupport::Concern

    included do
      has_one :user_extension, class_name: "Decidim::UserExtension", foreign_key: "decidim_user_id", inverse_of: "user", autosave: true, dependent: :destroy
    end
  end
end
