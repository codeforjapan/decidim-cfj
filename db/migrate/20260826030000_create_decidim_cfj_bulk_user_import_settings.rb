# frozen_string_literal: true

# 組織ごとの一括アカウント発行の設定（有効フラグとダミーメールのドメイン）。
# コアの decidim_organizations には手を入れず、cfj 独自のテーブルに分離する。
class CreateDecidimCfjBulkUserImportSettings < ActiveRecord::Migration[7.0]
  def change
    create_table :decidim_cfj_bulk_user_import_settings do |t|
      t.references :decidim_organization,
                   null: false,
                   index: { unique: true, name: "index_cfj_bulk_user_import_settings_on_organization" },
                   foreign_key: { to_table: :decidim_organizations }
      t.string :email_domain
      t.boolean :enabled, null: false, default: false

      t.timestamps
    end
  end
end
