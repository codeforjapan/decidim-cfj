# frozen_string_literal: true
# This migration comes from decidim_sortitions (originally 20171220164744)

class AddAdditionalInfoToSortitions < ActiveRecord::Migration[5.1]
  def change
    add_column :decidim_module_sortitions_sortitions, :additional_info, :jsonb
  end
end
