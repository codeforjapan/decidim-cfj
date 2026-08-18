# frozen_string_literal: true

# Decidim does not provide an order field for Decidim::Surveys::Survey yet, so
# the weights are kept outside of the core table. When upstream adds the column,
# migrating is a single UPDATE (see the removal steps in
# config/initializers/surveys_ordering_override.rb).
class CreateDecidimCfjSurveyOrders < ActiveRecord::Migration[7.0]
  def change
    create_table :decidim_cfj_survey_orders do |t|
      # decidim_surveys_surveys.id is a serial (integer), so the reference is an
      # integer as well to keep both sides of the foreign key on the same type.
      t.integer :decidim_surveys_survey_id, null: false
      t.integer :weight, null: false, default: 0

      t.timestamps
    end

    add_index :decidim_cfj_survey_orders,
              :decidim_surveys_survey_id,
              unique: true,
              name: "index_decidim_cfj_survey_orders_on_survey"

    add_foreign_key :decidim_cfj_survey_orders,
                    :decidim_surveys_surveys,
                    column: :decidim_surveys_survey_id,
                    on_delete: :cascade
  end
end
