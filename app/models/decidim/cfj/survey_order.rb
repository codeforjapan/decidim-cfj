# frozen_string_literal: true

module Decidim
  module Cfj
    # Holds the display order of a survey inside its component.
    #
    # Decidim::Surveys::Survey has no order attribute, so the weight lives in
    # this side table instead of the core one.
    class SurveyOrder < Decidim::ApplicationRecord
      self.table_name = "decidim_cfj_survey_orders"

      JOIN_SQL = <<~SQL.squish
        LEFT OUTER JOIN decidim_cfj_survey_orders
          ON decidim_cfj_survey_orders.decidim_surveys_survey_id = decidim_surveys_surveys.id
      SQL

      ORDER_SQL = <<~SQL.squish
        decidim_cfj_survey_orders.weight ASC NULLS LAST,
        decidim_surveys_surveys.id ASC
      SQL

      belongs_to :survey,
                 class_name: "Decidim::Surveys::Survey",
                 foreign_key: "decidim_surveys_survey_id",
                 inverse_of: false

      validates :weight, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

      def self.sorted(scope)
        scope.joins(JOIN_SQL).order(Arel.sql(ORDER_SQL))
      end

      def self.for_component(component)
        sorted(Decidim::Surveys::Survey.where(component:))
      end
    end
  end
end
