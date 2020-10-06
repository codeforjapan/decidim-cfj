# frozen_string_literal: true
# This migration comes from decidim (originally 20170913092351)

class AddHeaderSnippetsToOrganizations < ActiveRecord::Migration[5.1]
  def change
    add_column :decidim_organizations, :header_snippets, :text
  end
end
