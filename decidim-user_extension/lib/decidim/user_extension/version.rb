# frozen_string_literal: true

module Decidim
  module UserExtension
    VERSION = "0.4.0"

    def self.version
      Decidim::UserExtension::VERSION
    end

    def self.decidim_version
      ">= 0.27.4"
    end
  end
end
