# frozen_string_literal: true

# This migration comes from decidim_broadlistening_view (originally 20241220000000)
class CreateDecidimBroadlisteningViewReports < ActiveRecord::Migration[7.0]
  def change
    create_table :decidim_broadlistening_view_reports do |t|
      t.references :decidim_component, null: false, index: { name: "index_bl_view_reports_on_component_id" }
      t.string :title, null: false
      t.text :description
      t.jsonb :result_data, default: {}
      t.boolean :published, null: false, default: false

      t.timestamps
    end

    add_index :decidim_broadlistening_view_reports, :published
  end
end
