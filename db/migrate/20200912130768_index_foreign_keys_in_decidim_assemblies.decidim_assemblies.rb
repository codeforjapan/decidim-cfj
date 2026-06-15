# frozen_string_literal: true

# This migration comes from decidim_assemblies (originally 20200320105906)
# This file has been modified by `decidim upgrade:migrations` task on 2025-08-05 08:11:54 UTC
class IndexForeignKeysInDecidimAssemblies < ActiveRecord::Migration[5.2]
  def change
    add_index :decidim_assemblies, :decidim_scope_id
  end
end
