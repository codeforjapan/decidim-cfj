# frozen_string_literal: true

module Decidim
  module Ai
    module CommentModeration
      class Config
        class << self
          def enabled_for?(organization)
            return false unless organization

            enabled_hosts.include?(organization.host)
          end

          def enabled_hosts
            @enabled_hosts ||= ENV.fetch("DECIDIM_AI_MODERATION_ENABLED_HOSTS", "")
                                  .split(",")
                                  .map(&:strip)
                                  .reject(&:empty?)
          end
        end
      end
    end
  end
end
