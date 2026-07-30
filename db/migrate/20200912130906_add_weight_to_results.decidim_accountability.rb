# frozen_string_literal: true

# This migration comes from decidim_accountability (originally 20180508170210)
# This file has been modified by `decidim upgrade:migrations` task on 2025-08-05 08:11:54 UTC
class AddWeightToResults < ActiveRecord::Migration[5.1]
  def change
    add_column :decidim_accountability_results, :weight, :float, default: 1.0
  end
end
