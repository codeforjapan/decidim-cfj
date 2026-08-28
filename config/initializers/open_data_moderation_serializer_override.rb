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
#   1. reportable が解決できず nil になる
#      Decidim::Moderation#reportable はポリモーフィック関連で DB の外部キー制約を
#      張れないため、参照先が物理削除されると dangling になる。
#      加えて Decidim::Proposals::Proposal と Decidim::Meetings::Meeting は
#      SoftDeletable であり belongs_to :reportable に with_deleted が無いため、
#      「提案をゴミ箱に入れただけ」でも nil になる。実運用ではこちらの方が起きやすい。
#      いずれの経路でも例外ではなく nil が返る (実測確認済み)。
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
  # 例外クラスを列挙して絞ると URL 生成の別経路を取りこぼして同じ障害を繰り返す。
  # EngineRouter は route helper を method_missing で呼ぶため、NameError 系だけでなく
  # ActionController::UrlGenerationError も投げうる。よって StandardError を広く受ける。
  #
  # 一時的な DB 障害まで握って空の URL を公開データとして出す懸念はあるが、
  # 一時障害と恒久障害を例外クラスで判別するのは PostgreSQL では成立しない。
  # PostgreSQLAdapter#translate_exception が ConnectionNotEstablished に変換するのは
  # メッセージが /connection is closed/i に一致した場合だけで、実際の接続断
  # (server closed the connection unexpectedly) やデッドロックは素の
  # StatementInvalid に落ちる。逆に StatementInvalid には PG::UndefinedTable の
  # ような恒久的な失敗も含まれる。
  #
  # 代わりに、DB 障害はこの rescue を抜けた先で必ず顕在化することに依存する。
  # OpenDataExporter#data_for_all_resources は moderations の後に users /
  # user_groups / taxonomies と全コンポーネント・全空間を順に処理しており、
  # いずれも DB アクセスを伴う。接続が落ちていればそちらで例外になり ZIP は
  # 生成されないため、壊れたデータが正常な成果物として公開されることはない。
  def safe_reported_url
    reportable = resource.reportable

    if reportable.nil?
      # 物理削除とゴミ箱行きの両方がここに来る。どちらか断定できないため
      # 「解決できない」とだけ記録する。
      log_missing_reported_url("reportable could not be resolved (deleted or trashed)")
      return nil
    end

    reportable.reported_content_url
  rescue StandardError => e
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

Rails.application.config.to_prepare do
  Decidim::Exporters::OpenDataModerationSerializer.prepend(
    DecidimExportersOpenDataModerationSerializerNilReportablePatch
  )
end
