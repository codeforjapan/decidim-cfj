# frozen_string_literal: true

# Decidim::Exporters::OpenDataModerationSerializer の reported_url 生成が
# 壊れた参照で例外を投げ、オープンデータのエクスポート全体を落としている問題への対処。
#
# moderations の collection (decidim-core/lib/decidim/core.rb の open_data_manifests) は
# participatory_space と hidden でしか絞り込まないため、URL を生成できないレコードが
# 1 件でもあると ZIP 生成が moderations の時点で中断され、
# 提案も会議もユーザーも一切出力されなくなる。
#
# 到達しうる例外が単一ではないため、個別の nil ガードではなく
# reported_url の計算全体を rescue する。本番で確認できたのは以下の 2 経路。
#
#   1. reportable が nil
#      Decidim::Moderation#reportable はポリモーフィック関連で DB の外部キー制約を
#      張れないため、参照先が物理削除されると dangling になる。
#
#   2. reportable は残っているが reportable.component が nil
#      Decidim::Component は SoftDeletable (acts_as_paranoid) だが
#      Decidim::HasComponent の belongs_to :component は with_deleted を付けていない。
#      管理画面からコンポーネントをゴミ箱に入れると、中の提案やコメントは
#      trash されないまま component だけが引けなくなる。
#      その状態で reported_content_url を呼ぶと
#      ResourceLocatorPresenter#route_proxy が EngineRouter.main_proxy(component || target)
#      に target を渡し、Proposal/Comment は mounted_engine を持たないため
#      NoMethodError: undefined method `mounted_engine' になる。
#
# 本番実測 (hidden な moderation 88 件): 1 が 1 件、2 が 1 件。
# この 2 件のせいで該当する 2 組織のオープンデータが一切出力されていなかった。
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
        reported_url: safe_reported_url,
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

    private

    # URL 生成は壊れた参照で複数種類の例外を投げうる。
    # 1 レコードのために組織全体のエクスポートを止めないよう、握って nil を返す。
    #
    # rescue する例外は実際に観測した壊れ方に絞る。StandardError まで広げると
    # 一時的な DB エラー (ActiveRecord::StatementInvalid 等) も飲み込んでしまい、
    # 「参照が消えている」のか「引けなかっただけ」なのか区別できないまま
    # 空の URL を正常な公開データとして出力することになる。
    # NameError は NoMethodError (mounted_engine 不在) と
    # 型名を解決できないケースの両方を含む。
    def safe_reported_url
      reportable = resource.reportable

      if reportable.nil?
        log_missing_reported_url("dangling reportable")
        return nil
      end

      reportable.reported_content_url
    rescue NameError, ActiveRecord::RecordNotFound => e
      log_missing_reported_url("#{e.class}: #{e.message}")
      nil
    end

    def log_missing_reported_url(reason)
      Rails.logger.warn(
        "[open_data] failed to build reported_url for Decidim::Moderation " \
        "id=#{resource.id} reportable=#{resource.decidim_reportable_type}##{resource.decidim_reportable_id}: " \
        "#{reason}"
      )
    end
  end

  Decidim::Exporters::OpenDataModerationSerializer.prepend(
    DecidimExportersOpenDataModerationSerializerNilReportablePatch
  )
end
