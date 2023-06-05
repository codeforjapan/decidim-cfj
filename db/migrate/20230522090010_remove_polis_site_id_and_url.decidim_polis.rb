# frozen_string_literal: true
# This migration comes from decidim_polis (originally 20230508082639)

class RemovePolisSiteIdAndUrl < ActiveRecord::Migration[5.2]
  def change
    remove_column :decidim_organizations, :polis_site_id, :string
    remove_column :decidim_organizations, :polis_site_url, :string
  end
end
