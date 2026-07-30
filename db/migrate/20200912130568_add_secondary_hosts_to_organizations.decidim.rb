# frozen_string_literal: true

# This migration comes from decidim (originally 20170306144354)
# This file has been modified by `decidim upgrade:migrations` task on 2025-08-05 08:11:54 UTC
class AddSecondaryHostsToOrganizations < ActiveRecord::Migration[5.0]
  def change
    add_column :decidim_organizations, :secondary_hosts, :string, array: true, default: [], index: true
  end
end
