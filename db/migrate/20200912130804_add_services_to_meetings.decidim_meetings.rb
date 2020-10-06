# frozen_string_literal: true
# This migration comes from decidim_meetings (originally 20180407110934)

class AddServicesToMeetings < ActiveRecord::Migration[5.1]
  def change
    add_column :decidim_meetings_meetings, :services, :jsonb, default: []
  end
end
