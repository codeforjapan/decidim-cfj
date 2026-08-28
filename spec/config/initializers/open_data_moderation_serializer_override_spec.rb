# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Decidim::Exporters::OpenDataModerationSerializer nil reportable override" do
  subject { described_serializer.new(moderation).serialize }

  let(:described_serializer) { Decidim::Exporters::OpenDataModerationSerializer }

  let(:organization) { create(:organization) }
  let(:participatory_process) { create(:participatory_process, organization:) }
  let(:component) { create(:proposal_component, participatory_space: participatory_process) }

  context "when the moderation has an associated reportable" do
    let(:reportable) { create(:proposal, component:) }
    let(:moderation) { create(:moderation, :hidden, reportable:) }

    it "serializes the reported url" do
      expect(subject[:reported_url]).to eq(reportable.reported_content_url)
    end

    # override は serialize 全体を差し替えているため、上流がフィールドを追加したり
    # 値の算出方法を変えたりしても気づかずに取り残される。ハードコードした一覧と比べても
    # 「今の形」同士の比較にしかならないので、super_method で上流実装を直接呼んで
    # 戻り値ごと突き合わせる。
    it "matches the upstream output for a healthy record" do
      overridden = described_serializer.instance_method(:serialize).super_method

      # 親クラス Decidim::Exporters::Serializer も serialize を定義しているため、
      # override 未適用でも super_method は非 nil (親のメソッド) になる。
      # nil 判定では検知できないので owner を確認する。
      expect(overridden&.owner).to eq(described_serializer),
                                   "override が適用されていない。上流が修正済みなら initializer と本 spec を削除すること"

      upstream = overridden.bind(described_serializer.new(moderation)).call
      expect(subject).to eq(upstream)
    end
  end

  # Decidim::Moderation#reportable はポリモーフィック関連のため DB の外部キー制約を張れず、
  # 参照先が物理削除されると dangling になる。collection は hidden スコープで絞り込むだけで
  # reportable の存在を確認しないため、nil でも NoMethodError にならないこと。
  context "when the reportable no longer exists" do
    let(:reportable) { create(:proposal, component:) }
    let!(:moderation) { create(:moderation, :hidden, reportable:) }

    before do
      reportable.class.where(id: reportable.id).delete_all
      moderation.reload
    end

    it "has no reportable" do
      expect(moderation.reportable).to be_nil
    end

    it "does not raise and leaves the reported url empty" do
      expect { subject }.not_to raise_error
      expect(subject[:reported_url]).to be_nil
    end

    it "still serializes the moderation attributes" do
      expect(subject[:id]).to eq(moderation.id)
      expect(subject[:reportable_id]).to eq(reportable.id)
      expect(subject[:reportable_type]).to eq(reportable.class.name)
      expect(subject[:hidden_at]).to be_present
    end
  end

  # 例外クラスを列挙して絞ると別経路を取りこぼすため StandardError を広く受ける。
  # 一時障害と恒久障害は例外クラスで判別できない (PostgreSQL の接続断もデッドロックも
  # 素の StatementInvalid に落ちる) ので、ここでは区別せず握って nil を返す。
  # DB 障害はこの rescue を抜けた先の他マニフェスト処理で顕在化する。
  [
    [ActiveRecord::StatementInvalid, "server closed the connection unexpectedly"],
    [ActionController::UrlGenerationError, "no route matches"],
    [NoMethodError, "undefined method `mounted_engine'"]
  ].each do |error_class, message|
    context "when the url generation raises #{error_class}" do
      let(:reportable) { create(:proposal, component:) }
      let(:moderation) { create(:moderation, :hidden, reportable:) }

      before do
        allow(moderation).to receive(:reportable).and_return(reportable)
        allow(reportable).to receive(:reported_content_url).and_raise(error_class, message)
      end

      it "does not raise and leaves the reported url empty" do
        expect { subject }.not_to raise_error
        expect(subject[:reported_url]).to be_nil
      end
    end
  end

  # Decidim::Proposals::Proposal は SoftDeletable であり belongs_to :reportable に
  # with_deleted が無いため、ゴミ箱に入れるだけで reportable が nil になる。
  # 実運用ではこちらの方が物理削除より起きやすい。
  context "when the reportable has been trashed" do
    let(:reportable) { create(:proposal, component:) }
    let!(:moderation) { create(:moderation, :hidden, reportable:) }

    before do
      reportable.destroy
      moderation.reload
    end

    it "resolves the reportable to nil" do
      expect(moderation.reportable).to be_nil
    end

    it "does not raise and leaves the reported url empty" do
      expect { subject }.not_to raise_error
      expect(subject[:reported_url]).to be_nil
    end
  end

  # Decidim::Component は SoftDeletable だが Decidim::HasComponent の belongs_to は
  # with_deleted を付けていないため、管理画面からコンポーネントをゴミ箱に入れると
  # reportable は残ったまま reportable.component だけが nil になる。
  # その状態で reported_content_url を呼ぶと EngineRouter が target に対して
  # mounted_engine を呼び NoMethodError になる。
  context "when the reportable's component has been soft-deleted" do
    let(:reportable) { create(:proposal, component:) }
    let!(:moderation) { create(:moderation, :hidden, reportable:) }

    before do
      component.destroy
      moderation.reload
      reportable.reload
    end

    it "still resolves the reportable but not its component" do
      expect(moderation.reportable).to be_present
      expect(reportable.component).to be_nil
    end

    it "does not raise and leaves the reported url empty" do
      expect { subject }.not_to raise_error
      expect(subject[:reported_url]).to be_nil
    end

    it "still serializes the moderation attributes" do
      expect(subject[:id]).to eq(moderation.id)
      expect(subject[:reportable_id]).to eq(reportable.id)
      expect(subject[:hidden_at]).to be_present
    end
  end
end
