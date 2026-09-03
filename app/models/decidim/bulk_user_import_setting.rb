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
    # 生成されるメールアドレスがログインフォームのフロント検証（Foundation Abide の
    # email パターン）を通過できる形式に限定する。Abide はドメインにドット区切りの
    # 2ラベル以上（TLD 相当）を要求するので、ドットなしのドメイン（例: chiba-mirai）だと
    # 発行はできてもログイン画面で弾かれてしまう。実在するドメインと衝突しないよう、
    # RFC 2606 で予約されていてグローバル DNS には委任されない .test の使用を推奨する
    # （例: chiba-mirai.test。docs/BULK_SPACE_ACCOUNTS.md 参照）。
    EMAIL_DOMAIN_FORMAT = /\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+\z/

    validates :email_domain, format: { with: EMAIL_DOMAIN_FORMAT }, allow_blank: true
    validates :email_domain, presence: true, if: :enabled?
    validates :decidim_organization_id, uniqueness: true
  end
end
