# frozen_string_literal: true

# This migration comes from decidim (originally 20160920141151)
# This file has been modified by `decidim upgrade:migrations` task on 2025-08-05 08:11:54 UTC
class UserHasRoles < ActiveRecord::Migration[5.0]
  def change
    add_column :decidim_users, :roles, :string, array: true, default: []
  end
end
