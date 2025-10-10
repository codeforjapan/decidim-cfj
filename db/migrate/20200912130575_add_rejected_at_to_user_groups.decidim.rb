# frozen_string_literal: true

# This migration comes from decidim (originally 20170529150743)
# This file has been modified by `decidim upgrade:migrations` task on 2025-08-05 08:11:54 UTC
class AddRejectedAtToUserGroups < ActiveRecord::Migration[5.0]
  def change
    add_column :decidim_user_groups, :rejected_at, :datetime
  end
end
