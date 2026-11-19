# frozen_string_literal: true

# 0.32 で改名されたクラスの旧型名が管理ログと変更履歴に残り、管理ログが 500 になる
# （decidim#17728）。上流が書き換えない分を、新しい型名に書き換える。
class RenameOldTypesInLogs < ActiveRecord::Migration[7.0]
  RENAMES = {
    "Decidim::Accountability::TimelineEntry" => "Decidim::Accountability::Milestone",
    "Decidim::ParticipatorySpacePrivateUser" => "Decidim::ParticipatorySpace::Member",
    "Decidim::Proposals::ValuationAssignment" => "Decidim::Proposals::EvaluationAssignment"
  }.freeze

  class ActionLog < ApplicationRecord
    self.table_name = :decidim_action_logs
  end

  class Version < ApplicationRecord
    self.table_name = :versions
  end

  def up
    RENAMES.each { |from, to| rename_type(from, to) }
  end

  # 新しい型名のクラスは 0.30 に無く、テーブルも ID を保ったまま改名されているので全件戻せる。
  def down
    RENAMES.each { |from, to| rename_type(to, from) }
  end

  private

  def rename_type(from, to)
    # rubocop:disable Rails/SkipsModelValidations
    action_logs = ActionLog.where(resource_type: from).update_all(resource_type: to)
    versions = Version.where(item_type: from).update_all(item_type: to)
    # rubocop:enable Rails/SkipsModelValidations

    say "#{from} → #{to}: decidim_action_logs #{action_logs} 件、versions #{versions} 件"
  end
end
