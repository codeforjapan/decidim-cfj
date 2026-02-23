# frozen_string_literal: true

# This migration comes from decidim_meetings (originally 20180615160839)
# This file has been modified by `decidim upgrade:migrations` task on 2025-08-05 08:11:54 UTC
class AddCodeToDecidimMeetingsRegistrations < ActiveRecord::Migration[5.2]
  def change
    add_column :decidim_meetings_registrations, :code, :string, index: true
  end
end
