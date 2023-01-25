# frozen_string_literal: true

module Decidim
  module Proposals
    module CfjOrderable
      private

      def default_order
        order_by_query_param || order_by_cookie || super
      end

      def order_by_query_param
        param = params[:orderable]
        param if param && available_orders.include?(param)
      end

      def order_by_cookie
        cookie = cookies[order_cookie_name]
        param = params[:orderable]
        cookie if cookie && available_orders.include?(cookie)
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
