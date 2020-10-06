# frozen_string_literal: true
# This migration comes from decidim (originally 20170912082054)

class AddEmailsOnNotificationsFlagToUser < ActiveRecord::Migration[5.1]
  def change
    add_column :decidim_users, :email_on_notification, :boolean, default: false, null: false
  end
end
