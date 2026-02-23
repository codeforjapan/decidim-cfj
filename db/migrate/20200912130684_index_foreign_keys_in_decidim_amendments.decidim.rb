# frozen_string_literal: true

# This migration comes from decidim (originally 20200320105905)
# This file has been modified by `decidim upgrade:migrations` task on 2025-08-05 08:11:54 UTC
class IndexForeignKeysInDecidimAmendments < ActiveRecord::Migration[5.2]
  def change
    add_index :decidim_amendments, :decidim_emendation_id
  end
end
