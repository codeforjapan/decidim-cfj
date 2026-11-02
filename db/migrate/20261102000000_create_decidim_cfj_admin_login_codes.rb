# frozen_string_literal: true

# One-time codes emailed to users entering the admin panel (second step after sign in),
# and the lock applied to the admin panel after too many wrong codes.
class CreateDecidimCfjAdminLoginCodes < ActiveRecord::Migration[7.0]
  def change
    create_table :decidim_cfj_admin_login_codes do |t|
      t.references :decidim_user,
                   null: false,
                   index: { unique: true, name: "index_cfj_admin_login_codes_on_user" },
                   foreign_key: { to_table: :decidim_users, on_delete: :cascade }
      t.string :code_digest
      t.datetime :sent_at
      t.integer :failed_attempts, null: false, default: 0
      t.integer :total_failed_attempts, null: false, default: 0
      t.datetime :locked_at

      t.timestamps
    end
  end
end
