# frozen_string_literal: true

# This migration comes from decidim_participatory_processes (originally 20170725085104)
# This file has been modified by `decidim upgrade:migrations` task on 2025-08-05 08:11:54 UTC
class AddShowStatisticsToParticipatoryProcesses < ActiveRecord::Migration[5.1]
  def change
    add_column :decidim_participatory_processes, :show_statistics, :boolean, default: true
  end
end
