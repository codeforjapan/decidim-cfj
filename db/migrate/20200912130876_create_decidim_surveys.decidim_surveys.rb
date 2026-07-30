# frozen_string_literal: true

# This migration comes from decidim_surveys (originally 20170511092231)
# This file has been modified by `decidim upgrade:migrations` task on 2025-08-05 08:11:54 UTC
class CreateDecidimSurveys < ActiveRecord::Migration[5.0]
  def change
    create_table :decidim_surveys_surveys do |t|
      t.jsonb :title
      t.jsonb :description
      t.jsonb :tos
      t.references :decidim_feature, index: true
      t.datetime :published_at

      t.timestamps
    end
  end
end
