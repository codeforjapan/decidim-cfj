# frozen_string_literal: true

# decidim-ai のスパム判定が sidekiq の並行実行で混線する問題への対処。
#
# Decidim::Ai::StrategyRegistry は boot 時に strategy を 1 インスタンスだけ生成して保持する
# (decidim-ai/lib/decidim/ai/strategy_registry.rb の `strategies << strategy.new(options)`)。
# Decidim::Ai::SpamDetection.resource_classifier は呼ばれるたびに新しい Service を返すが、
# 包んでいるレジストリは `@resource_registry ||=` でメモ化されているため、
# Service を作り直しても中の Strategy::Bayes は全ジョブで同一オブジェクトになる。
#
# Strategy::Bayes は判定結果を自身の @category / @internal_score に書き、
# #score と #log がそれを読む。
#
#   def classify(content)
#     @category, @internal_score = backend.classify_with_score(content)
#   end
#   def score = category.presence == "spam" ? 1 : 0
#
# 一方 GenericSpamAnalyzerJob は「書く」と「読む」を別の行で行う。
#
#   fields.map do |field|
#     classifier.classify(...)   # ここで @category を書き
#     classifier.score           # ここで読む。この間に別スレッドが classify すると壊れる
#   end
#   ...
#   Decidim::ReportForm.new(reason: "spam", details: classifier.classification_log)
#                                                    # 判定確定後にもう一度読む
#
# config/sidekiq.yml は concurrency 3 で spam_analysis キューを処理するため、
# 同時刻に投稿が重なると別ジョブの判定結果を読む。結果として
# 正常な投稿が spam として通報される / スパムを取りこぼす、のどちらも起こりうる。
# 通報の details も対象と無関係な文言になり、管理画面のモデレーション一覧は
# 理由・ロケール・details しか表示しないため、モデレーターが誤読する。
#
# ローカルで実証した挙動 (Service インスタンスは別物、strategy は同一):
#
#   a.classify(SPAM) 直後   -> a.score=1.0  a.log="marked this as spam"
#   b.classify(HAM) のあと  -> a.score=0.0  a.log="marked this as ham"
#
# 対処として、ジョブが使う分類器をスレッドごとに独立させる。
# レジストリを都度作り直すことで Strategy::Bayes もスレッドごとに別インスタンスになる。
# スレッドローカルに持たせるのは、ジョブごとに生成すると
# ClassifierReborn::BayesRedisBackend の Redis 接続が使い捨てになるため。
# sidekiq のスレッドは長命なので、接続数は concurrency × 分類器の種類で頭打ちになる。
#
# 上流 develop (0.33.0.dev) 時点でも bayes.rb / strategy_registry.rb は同一実装で未修正。
# 本来は classify の戻り値を使い score / log を状態に依存させない形が筋だが、
# API 変更になるため上流に投げたうえで、こちらでは呼び出し側を隔離するに留める。
#
# NOTE: UserSpamAnalyzerJob は classifier を自前で定義しており、
# サブクラスのメソッドのほうが祖先チェーンで先に来る。ApplicationJob への prepend だけでは
# 効かないため、同クラスにも個別に prepend する。
Rails.application.config.to_prepare do
  Decidim::Ai::SpamDetection::ApplicationJob # rubocop:disable Lint/Void
  Decidim::Ai::SpamDetection::UserSpamAnalyzerJob # rubocop:disable Lint/Void

  module DecidimAiSpamDetectionIsolatedClassifier
    private

    def build_isolated_classifier(analyzers, detection_service)
      registry = Decidim::Ai::StrategyRegistry.new
      analyzers.each { |analyzer| registry.register_analyzer(**analyzer) }
      detection_service.safe_constantize.new(registry:)
    end
  end

  module DecidimAiSpamDetectionResourceClassifierPerThread
    include DecidimAiSpamDetectionIsolatedClassifier

    THREAD_KEY = :decidim_cfj_spam_detection_resource_classifier

    protected

    def classifier
      Thread.current[THREAD_KEY] ||= build_isolated_classifier(
        Decidim::Ai::SpamDetection.resource_analyzers,
        Decidim::Ai::SpamDetection.resource_detection_service
      )
    end
  end

  module DecidimAiSpamDetectionUserClassifierPerThread
    include DecidimAiSpamDetectionIsolatedClassifier

    THREAD_KEY = :decidim_cfj_spam_detection_user_classifier

    protected

    def classifier
      Thread.current[THREAD_KEY] ||= build_isolated_classifier(
        Decidim::Ai::SpamDetection.user_analyzers,
        Decidim::Ai::SpamDetection.user_detection_service
      )
    end
  end

  Decidim::Ai::SpamDetection::ApplicationJob.prepend(
    DecidimAiSpamDetectionResourceClassifierPerThread
  )
  Decidim::Ai::SpamDetection::UserSpamAnalyzerJob.prepend(
    DecidimAiSpamDetectionUserClassifierPerThread
  )
end
