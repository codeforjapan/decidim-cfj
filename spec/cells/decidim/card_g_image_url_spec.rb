# frozen_string_literal: true

require "rails_helper"

# コンポーネント配下のページで、ハイライトカードの画像 URL が
# /ja/processes/:slug/f/:id/rails/active_storage/... になっていた回帰のカバー。
#
# ビュー文脈の rails_blob_path はリクエスト由来の SCRIPT_NAME(エンジンのマウント位置)を
# 前置する。トップページでは SCRIPT_NAME が空なので表面化せず、コンポーネント配下の
# ページだけで壊れていた。Rails.application.routes から生成すればビュー文脈に依存しない。
describe "ハイライトカードの画像 URL" do
  let(:organization) { create(:organization) }
  let(:polluted) { "/ja/processes/foo/f/1592/rails/active_storage/blobs/proxy/polluted" }

  shared_examples "ビュー文脈の SCRIPT_NAME に汚染されない" do
    it "/rails/active_storage から始まる絶対パスを返す" do
      cell = described_class.new(model, context: {})
      # ビューのヘルパーを使っていたら、この戻り値がそのまま出てしまう
      allow(cell).to receive(:rails_blob_path).and_return(polluted)

      url = cell.send(:resource_image_url)

      expect(url).to start_with("/rails/active_storage/")
      expect(url).not_to include("/f/")
    end

    it "添付が無ければ nil を返す" do
      model.hero_image.purge
      cell = described_class.new(model.reload, context: {})

      expect(cell.send(:resource_image_url)).to be_nil
    end
  end

  describe Decidim::ParticipatoryProcesses::ProcessGCell do
    let(:model) { create(:participatory_process, organization:) }

    it_behaves_like "ビュー文脈の SCRIPT_NAME に汚染されない"
  end

  describe Decidim::Assemblies::AssemblyGCell do
    let(:model) { create(:assembly, organization:) }

    it_behaves_like "ビュー文脈の SCRIPT_NAME に汚染されない"
  end
end
