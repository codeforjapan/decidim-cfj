# frozen_string_literal: true
# This migration comes from decidim_polis (originally 20220920152159)

class AddPolisSiteUrlToOrganizations < ActiveRecord::Migration[5.2]
  def change
    add_column :decidim_organizations, :polis_site_url, :string
  end
end
