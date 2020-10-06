# frozen_string_literal: true
# This migration comes from decidim_debates (originally 20180122090505)

class AddUserGroupAuthorToDebates < ActiveRecord::Migration[5.1]
  def change
    add_column :decidim_debates_debates, :decidim_user_group_id, :integer
  end
end
