# frozen_string_literal: true

module Decidim
  module Cfj
    # A command that reorders the surveys of a component.
    #
    # It mirrors Decidim::Admin::ReorderComponents, with two differences: the
    # weights are written to the decidim_cfj_survey_orders side table instead of
    # a column of the reordered records, and the given order only covers the
    # surveys of the page the admin is looking at, because the index is
    # paginated.
    #
    # Surveys with no weight are displayed last, so writing weights for the
    # reordered page alone would push the surveys of the previous pages behind
    # it. To keep the whole collection consistent, every survey gets the weight
    # matching the position it is currently displayed at, and the reordered ones
    # are then written back to the positions they already occupied. The current
    # order is resolved from the component, so nothing has to be trusted from
    # the request beyond the ids themselves.
    class ReorderSurveys < Decidim::Command
      def initialize(component, order)
        @component = component
        @order = order
      end

      def call
        return broadcast(:invalid) unless order.is_a?(Array)
        return broadcast(:invalid) if reordered_ids.blank?

        persist(weights)
        broadcast(:ok)
      end

      private

      attr_reader :component, :order

      def weights
        weights = displayed_ids.each_with_index.to_h { |id, index| [id, index + 1] }
        positions = reordered_ids.map { |id| weights[id] }.sort
        reordered_ids.each_with_index { |id, index| weights[id] = positions[index] }

        weights
      end

      # The whole collection is rewritten on every reorder, so this is a single
      # statement. The weights are derived positions, never user input, which is
      # why skipping the model validation is safe here.
      def persist(weights)
        # rubocop:disable Rails/SkipsModelValidations
        SurveyOrder.upsert_all(
          weights.map { |id, weight| { decidim_surveys_survey_id: id, weight: } },
          unique_by: :index_decidim_cfj_survey_orders_on_survey,
          record_timestamps: true
        )
        # rubocop:enable Rails/SkipsModelValidations
      end

      def displayed_ids
        @displayed_ids ||= SurveyOrder.for_component(component).pluck(:id)
      end

      def reordered_ids
        @reordered_ids ||= order.filter_map { |id| Integer(id, exception: false) }.uniq & displayed_ids
      end
    end
  end
end
