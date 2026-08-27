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

    # override は serialize 全体を差し替えているため、上流がフィールドを追加しても
    # 気づかずに欠落しうる。ハードコードした一覧と比べても「今の形」同士の比較にしかならず
    # 上流の変更を検知できないので、super_method で上流実装を直接呼んで突き合わせる。
    it "keeps the upstream key set" do
      serializer = described_serializer.new(moderation)
      upstream = described_serializer.instance_method(:serialize).super_method.bind(serializer).call

      expect(subject.keys).to match_array(upstream.keys)
      expect(subject[:reports].keys).to match_array(upstream[:reports].keys)
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
