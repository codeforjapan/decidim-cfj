# frozen_string_literal: true

# This migration comes from decidim_proposals (originally 20170120151202)
# This file has been modified by `decidim upgrade:migrations` task on 2025-08-05 08:11:54 UTC
class AddUserGroupIdToProposals < ActiveRecord::Migration[5.0]
  def change
    add_column :decidim_proposals_proposals, :decidim_user_group_id, :integer, index: true
  end
end
