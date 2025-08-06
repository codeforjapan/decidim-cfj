# frozen_string_literal: true

# This migration comes from decidim (originally 20170110133113)
# This file has been modified by `decidim upgrade:migrations` task on 2025-08-05 08:11:54 UTC
class AddConfigurationToFeatures < ActiveRecord::Migration[5.0]
  def change
    change_table :decidim_features do |t|
      t.jsonb :settings, default: {}
    end
  end
end
