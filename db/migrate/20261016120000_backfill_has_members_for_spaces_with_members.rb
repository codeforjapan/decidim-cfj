# frozen_string_literal: true

# 0.32 で参加スペースに has_members 列が入ったが、上流のマイグレーションは
# default: false で列を足すだけで、既存データを埋め戻さない
# （decidim 20251205120000 / 20251205120001。v0.32.1 にも develop にも埋め戻しは無い）。
#
# 旧 decidim_participatory_space_private_users のデータは decidim_members へ移送される
# ので、メンバーは今までどおりスペースに入れる（can_participate? は has_members を見ず
# members の実在を見る）。壊れるのは管理側で、permissions.rb の user_can_read_members? が
# `return unless space.has_members?` で止まるため、メンバーの追加・削除・CSV インポートが
# 一切できなくなる。公開側のメンバー一覧（members_public_page?）も出ない。
#
# 本番データでは 138 スペース（最大 465 名）が該当した。
#
# access_mode ではなくメンバーの実在を条件にする。access_mode=open のスペースにも
# メンバーを持つものがあるため。条件が「メンバーが居るのに false」なので再実行しても安全。
class BackfillHasMembersForSpacesWithMembers < ActiveRecord::Migration[7.0]
  SPACE_TABLES = {
    "decidim_participatory_processes" => "Decidim::ParticipatoryProcess",
    "decidim_assemblies" => "Decidim::Assembly"
  }.freeze

  def up
    return unless table_exists?(:decidim_members)

    SPACE_TABLES.each do |table, space_type|
      next unless table_exists?(table) && column_exists?(table, :has_members)

      updated = execute(<<~SQL.squish).cmd_tuples
        UPDATE #{table} SET has_members = TRUE
        WHERE has_members IS NOT TRUE
          AND id IN (
            SELECT DISTINCT participatory_space_id FROM decidim_members
            WHERE participatory_space_type = #{quote(space_type)}
          )
      SQL

      say "#{table}: #{updated} 件の has_members を true にしました"
    end
  end

  def down
    # 戻さない。false が「メンバー不在」由来か「上流の既定値」由来かを区別できないため。
  end
end
