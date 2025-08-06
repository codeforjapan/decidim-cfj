# frozen_string_literal: true

# This migration comes from decidim (originally 20200320105923)
# This file has been modified by `decidim upgrade:migrations` task on 2025-08-05 08:11:54 UTC
class IndexForeignKeysInDecidimNotifications < ActiveRecord::Migration[5.2]
  def change
    add_index :decidim_notifications, :decidim_resource_id
  end
end
