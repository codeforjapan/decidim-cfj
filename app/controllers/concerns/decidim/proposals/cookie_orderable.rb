# frozen_string_literal: true

module Decidim
  module Proposals
    module CookieOrderable
      private

      def default_order
        order_by_cookie || super
      end

      def order_by_cookie
        cookie = cookies[order_cookie_name]
        cookie if cookie && possible_orders.include?(cookie)
      end

      def order_cookie_name
        "proposal_default_order"
      end

      def detect_order(candidate)
        detected = available_orders.detect { |order| order == candidate }
        cookies[order_cookie_name] = detected if detected
        detected
      end
    end
  end
end
