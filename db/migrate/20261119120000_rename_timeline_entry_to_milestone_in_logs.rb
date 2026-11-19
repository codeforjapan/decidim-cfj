# frozen_string_literal: true

# 0.32 で Decidim::Accountability::TimelineEntry が Milestone に改名されたが、上流は
# 管理ログと変更履歴の型名を書き換えないため、旧型名のまま残った記録で管理ログが 500 になる
# （decidim#17728）。
class RenameTimelineEntryToMilestoneInLogs < ActiveRecord::Migration[7.0]
  OLD_TYPE = "Decidim::Accountability::TimelineEntry"
  NEW_TYPE = "Decidim::Accountability::Milestone"

  class ActionLog < ApplicationRecord
    self.table_name = :decidim_action_logs
  end

  class Version < ApplicationRecord
    self.table_name = :versions
  end

  def up
    # rubocop:disable Rails/SkipsModelValidations
    action_logs = ActionLog.where(resource_type: OLD_TYPE).update_all(resource_type: NEW_TYPE)
    versions = Version.where(item_type: OLD_TYPE).update_all(item_type: NEW_TYPE)
    # rubocop:enable Rails/SkipsModelValidations

    say "decidim_action_logs: #{action_logs} 件、versions: #{versions} 件を #{NEW_TYPE} に書き換えました"
  end

  # 移行後に作られた Milestone の記録と区別できないため戻さない。
  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
