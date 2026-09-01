# frozen_string_literal: true

module Decidim
  # 組織ごとの一括アカウント発行（bulk_users:issue）の設定。
  # /system（大元の管理画面）から編集できるようにする想定（UIは別PR）。
  # それまでは rake bulk_users:configure で設定する。
  class BulkUserImportSetting < ApplicationRecord
    self.table_name = "decidim_cfj_bulk_user_import_settings"

    belongs_to :organization,
               class_name: "Decidim::Organization",
               foreign_key: :decidim_organization_id,
               inverse_of: false

    # ドメインはログインID（メール形式）の一部としてそのまま配布されるため、
    # Devise のメール形式（/\A[^@\s]+@[^@\s]+\z/）を壊す文字を弾いておく。
    validates :email_domain, format: { with: /\A[a-z0-9][a-z0-9.-]*\z/ }, allow_blank: true
    validates :email_domain, presence: true, if: :enabled?
    validates :decidim_organization_id, uniqueness: true
  end
end
