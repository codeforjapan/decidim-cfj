# frozen_string_literal: true

# This migration comes from decidim_participatory_processes (originally 20180125102537)
# This file has been modified by `decidim upgrade:migrations` task on 2025-08-05 08:11:54 UTC
class AddReferenceToProcesses < ActiveRecord::Migration[5.1]
  def change
    add_column :decidim_participatory_processes, :reference, :string
  end
end
