# frozen_string_literal: true
# This migration comes from decidim_surveys (originally 20180314225829)

class AddMaxChoicesToSurveyQuestions < ActiveRecord::Migration[5.1]
  def change
    add_column :decidim_surveys_survey_questions, :max_choices, :integer
  end
end
