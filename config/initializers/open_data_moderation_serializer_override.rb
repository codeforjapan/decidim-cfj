# frozen_string_literal: true

# Decidim::Exporters::OpenDataModerationSerializer が `resource.reportable` の nil を
# 想定しておらず、オープンデータのエクスポート全体を落としている問題への対処。
#
# Decidim::Moderation#reportable はポリモーフィック関連のため DB の外部キー制約を張れず、
# 参照先 (提案・コメント等) が物理削除されると dangling になる。
# moderations の collection (decidim-core/lib/decidim/core.rb の open_data_manifests) は
# hidden スコープで絞り込むだけで reportable の存在を確認しないため、
# 1 件でも壊れたレコードがあると NoMethodError になり ZIP 生成が中断される。
#
# 本番実測: hidden な moderation 88 件のうち reportable が nil なのは 1 件だけだが、
# その 1 件のせいで当該組織のオープンデータが一切出力されなくなっていた。
#
# decidim 0.30.9 / 0.31.7 / 0.32.1 / develop のいずれでも当該 serializer は
# 同一内容で未修正のため、上流追従では解消しない (上流 issue: decidim/decidim#17574)。
#
# NOTE: 元実装が `resource.reportable.reported_content_url` を直接呼ぶ構造のため
# super は使えない (super の中で例外が起きる)。serialize 全体を差し替える。
# 元は decidim-core/app/serializers/decidim/exporters/open_data_moderation_serializer.rb
# の v0.30.9 時点の実装で、v0.31.7 / v0.32.1 とも差分なし。
Rails.application.config.to_prepare do
  Decidim::Exporters::OpenDataModerationSerializer # rubocop:disable Lint/Void

  module DecidimExportersOpenDataModerationSerializerNilReportablePatch
    def serialize
      {
        id: resource.id,
        hidden_at: resource.hidden_at,
        report_count: resource.report_count,
        reported_url: resource.reportable&.reported_content_url,
        reportable_type: resource.decidim_reportable_type,
        reportable_id: resource.decidim_reportable_id,
        reported_content: resource.reported_content,
        reports: {
          reasons: resource.reports.map(&:reason),
          locale: resource.reports.map(&:locale),
          details: resource.reports.map(&:details)
        }
      }
    end
  end

  Decidim::Exporters::OpenDataModerationSerializer.prepend(
    DecidimExportersOpenDataModerationSerializerNilReportablePatch
  )
end
