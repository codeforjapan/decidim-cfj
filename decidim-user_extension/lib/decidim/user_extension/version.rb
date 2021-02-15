# frozen_string_literal: true

module Decidim
  module UserExtension
    VERSION = "0.1.0"

    def self.version
      Decidim::UserExtension::VERSION
    end

    def self.decidim_version
      ">= 0.23.0"
    end
  end
end
