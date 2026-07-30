# frozen_string_literal: true

# This migration comes from decidim_surveys (originally 20170525132233)
# This file has been modified by `decidim upgrade:migrations` task on 2025-08-05 08:11:54 UTC
class AddAnswerOptionsToSurveysQuestions < ActiveRecord::Migration[5.0]
  def change
    add_column :decidim_surveys_survey_questions, :answer_options, :jsonb, default: []
  end
end
