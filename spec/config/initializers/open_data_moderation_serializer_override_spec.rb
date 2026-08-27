# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Decidim::Exporters::OpenDataModerationSerializer nil reportable override" do
  subject { Decidim::Exporters::OpenDataModerationSerializer.new(moderation).serialize }

  let(:organization) { create(:organization) }
  let(:participatory_process) { create(:participatory_process, organization:) }
  let(:component) { create(:proposal_component, participatory_space: participatory_process) }

  context "when the moderation has an associated reportable" do
    let(:reportable) { create(:proposal, component:) }
    let(:moderation) { create(:moderation, :hidden, reportable:) }

    it "serializes the reported url" do
      expect(subject[:reported_url]).to eq(reportable.reported_content_url)
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
end
