# frozen_string_literal: true

require "rails_helper"

# config/initializers/spam_detection_classifier_isolation.rb
#
# decidim-ai は Strategy::Bayes を boot 時に 1 インスタンスだけ生成し、判定結果を
# そのインスタンス変数に保持する。ジョブは classify と score を別の行で呼ぶため、
# sidekiq の並行実行 (config/sidekiq.yml は concurrency 3) で別ジョブの結果を読む。
# ここでは「スレッドごとに分類器が独立していること」と「元の判定が壊れていないこと」を見る。
describe "Spam detection classifier isolation" do
  # Redis を使わずに完結させるため memory バックエンドに差し替える。
  # 上流の既定も CI では memory を使う想定になっている。
  def memory_analyzers
    [{
      name: :bayes,
      strategy: Decidim::Ai::SpamDetection::Strategy::Bayes,
      options: { adapter: :memory, params: {} }
    }]
  end

  def clear_thread_caches
    [
      DecidimAiSpamDetectionResourceClassifierPerThread::THREAD_KEY,
      DecidimAiSpamDetectionUserClassifierPerThread::THREAD_KEY
    ].each { |key| Thread.current[key] = nil }
  end

  let(:spam_text) { "副収入をお探しの方へ。スマホ一台で毎日3万円。登録は30秒、ノルマなし。" }
  let(:ham_text) { "小学校の通学路に横断歩道の設置をお願いしたいです。交通量が多く危険です。" }

  let(:job) { Decidim::Ai::SpamDetection::GenericSpamAnalyzerJob.new }

  around do |example|
    original_resource = Decidim::Ai::SpamDetection.resource_analyzers
    original_user = Decidim::Ai::SpamDetection.user_analyzers
    Decidim::Ai::SpamDetection.resource_analyzers = memory_analyzers
    Decidim::Ai::SpamDetection.user_analyzers = memory_analyzers
    clear_thread_caches

    example.run

    Decidim::Ai::SpamDetection.resource_analyzers = original_resource
    Decidim::Ai::SpamDetection.user_analyzers = original_user
    clear_thread_caches
  end

  # 学習させないと classify が常に同じ結果を返し、混線しても差が出ない。
  def trained_classifier_for(job_instance)
    classifier = job_instance.send(:classifier)
    classifier.train(:spam, spam_text)
    classifier.train(:ham, ham_text)
    classifier
  end

  describe "スレッド単位の隔離" do
    it "同じスレッドでは分類器を使い回す" do
      expect(job.send(:classifier)).to be(Decidim::Ai::SpamDetection::GenericSpamAnalyzerJob.new.send(:classifier))
    end

    it "スレッドが違えば別の分類器になる" do
      main = job.send(:classifier)
      other = Thread.new { Decidim::Ai::SpamDetection::GenericSpamAnalyzerJob.new.send(:classifier) }.value

      expect(other).not_to be(main)
    end

    # レジストリを共有すると Service を作り直しても Strategy が同一になり、
    # 隔離した意味がなくなる。
    it "グローバルのレジストリに登録された strategy を共有しない" do
      global = Decidim::Ai::SpamDetection.resource_registry.collect(&:itself)
      mine = job.send(:classifier).instance_variable_get(:@registry).collect(&:itself)

      expect(mine).to all(satisfy { |strategy| global.none? { |g| g.equal?(strategy) } })
    end

    it "user 分類器は resource 分類器と別インスタンスになる" do
      user_job = Decidim::Ai::SpamDetection::UserSpamAnalyzerJob.new

      expect(user_job.send(:classifier)).not_to be(job.send(:classifier))
    end
  end

  describe "並行して分類しても結果が壊れない" do
    # 修正前は Strategy が共有されるため、片方の classify がもう片方の score を
    # 上書きして score=0 になる。
    it "別スレッドの classify に score を上書きされない" do
      trained_classifier_for(job)

      ready = Queue.new
      resume = Queue.new

      other = Thread.new do
        other_classifier = trained_classifier_for(Decidim::Ai::SpamDetection::GenericSpamAnalyzerJob.new)
        ready.pop
        other_classifier.classify(ham_text)
        resume << :done
      end

      classifier = job.send(:classifier)
      classifier.classify(spam_text)
      ready << :go
      resume.pop

      expect(classifier.score).to eq(1)
      expect(classifier.classification_log).to include("spam")

      other.join
    end
  end

  describe "元の判定が壊れていないこと" do
    it "スパムらしい文面を spam と判定する" do
      classifier = trained_classifier_for(job)
      classifier.classify(spam_text)

      expect(classifier.score).to eq(1)
      expect(classifier.score).to be >= Decidim::Ai::SpamDetection.resource_score_threshold
    end

    it "通常の投稿を spam と判定しない" do
      classifier = trained_classifier_for(job)
      classifier.classify(ham_text)

      expect(classifier.score).to eq(0)
      expect(classifier.score).to be < Decidim::Ai::SpamDetection.resource_score_threshold
    end

    it "classification_log が直前の判定と一致する" do
      classifier = trained_classifier_for(job)

      classifier.classify(spam_text)
      expect(classifier.classification_log).to include("spam")

      classifier.classify(ham_text)
      expect(classifier.classification_log).to include("ham")
    end
  end
end
