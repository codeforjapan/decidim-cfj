# frozen_string_literal: true

module Decidim
  module UserExtension
    VERSION = "0.2.0"

    def self.version
      Decidim::UserExtension::VERSION
    end

    def self.decidim_version
      ">= 0.25.2"
    end
  end
end
