class ChangeDirectMessageTypesToUsers < ActiveRecord::Migration[5.2]
  def change
    change_column :decidim_users, :direct_message_types, :string, default: "followed-only"
    # rubocop:disable Rails/SkipsModelValidations
    Decidim::UserBaseEntity.update_all(direct_message_types: "followed-only")
    # rubocop:enable Rails/SkipsModelValidations
  end
end
