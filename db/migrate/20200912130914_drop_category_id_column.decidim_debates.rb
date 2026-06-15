# frozen_string_literal: true

# This migration comes from decidim_debates (originally 20180305092347)
# This file has been modified by `decidim upgrade:migrations` task on 2025-08-05 08:11:54 UTC
class DropCategoryIdColumn < ActiveRecord::Migration[5.1]
  def change
    remove_column :decidim_debates_debates, :decidim_category_id
  end
end
