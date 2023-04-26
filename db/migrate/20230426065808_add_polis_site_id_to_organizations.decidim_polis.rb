# frozen_string_literal: true
# This migration comes from decidim_polis (originally 20180301065746)

class AddPolisSiteIdToOrganizations < ActiveRecord::Migration[5.1]
  def change
    add_column :decidim_organizations, :polis_site_id, :string
  end
end
