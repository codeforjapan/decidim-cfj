# frozen_string_literal: true

# This migration comes from decidim (originally 20170605140421)
# This file has been modified by `decidim upgrade:migrations` task on 2025-08-05 08:11:54 UTC
class AddDeletedFieldsToUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :decidim_users, :delete_reason, :text
    add_column :decidim_users, :deleted_at, :datetime
  end
end
