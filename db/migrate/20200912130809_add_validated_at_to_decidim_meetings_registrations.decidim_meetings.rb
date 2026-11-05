# frozen_string_literal: true

# This migration comes from decidim_meetings (originally 20180711111023)
# This file has been modified by `decidim upgrade:migrations` task on 2025-08-05 08:11:54 UTC
class AddValidatedAtToDecidimMeetingsRegistrations < ActiveRecord::Migration[5.2]
  def change
    add_column :decidim_meetings_registrations, :validated_at, :datetime
  end
end
