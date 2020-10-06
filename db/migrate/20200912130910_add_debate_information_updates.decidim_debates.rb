# frozen_string_literal: true
# This migration comes from decidim_debates (originally 20180117100413)

class AddDebateInformationUpdates < ActiveRecord::Migration[5.1]
  def change
    add_column :decidim_debates_debates, :information_updates, :jsonb
  end
end
