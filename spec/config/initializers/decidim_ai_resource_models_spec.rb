# frozen_string_literal: true

require "rails_helper"

# config/initializers/decidim_ai.rb
#
# resource_models に未導入モジュールのモデルが混ざっていると、
# decidim:ai:spam:train_application_database がハッシュの途中で止まる。
# 先頭の Comment だけ学習された中途半端な状態で落ちるため、気づきにくい。
#
# 実際に decidim-initiatives 未導入の状態で "Decidim::Initiative" が残っており、
# 本番で学習タスクが完走できない状態だった。登録内容が実際に解決できることを見張る。
#
# NOTE: user_models は decidim-ai 0.30.9 では定義されているだけで一度も読まれない
# (Importer::Database が見るのは resource_models のみ)。いま壊れても実害は出ないが、
# 設定として存在する以上は整合を保ちたいので同じ検査をかけておく。
describe "decidim-ai registered models" do
  shared_examples "resolvable handlers" do |models|
    it "モデル名がすべて解決できる" do
      models.each_key do |model_name|
        expect { model_name.constantize }.not_to raise_error, "#{model_name} を解決できない"
      end
    end

    # 実際に NameError を投げるのはここ。decidim-ai がキーを constantize する箇所は無く、
    # Importer::Database は values しか見ないため、query の解決が本質的な検証になる。
    it "ハンドラがすべて解決でき、batch_train の前提を満たす" do
      models.each_value do |handler_name|
        handler = handler_name.constantize.new

        # batch_train は query と fields の両方を使う。
        expect(handler.fields).to be_present, "#{handler_name}#fields が空"
        expect { handler.send(:query) }.not_to raise_error, "#{handler_name}#query を解決できない"
      end
    end
  end

  describe "resource_models" do
    include_examples "resolvable handlers", Decidim::Ai::SpamDetection.resource_models
  end

  describe "user_models" do
    include_examples "resolvable handlers", Decidim::Ai::SpamDetection.user_models
  end

  # 未導入モジュールが紛れ込む事故そのものを検知する。
  it "未導入モジュールのモデルを含まない" do
    uninstalled = Decidim::Ai::SpamDetection.resource_models.keys.reject do |model_name|
      model_name.safe_constantize.present?
    end

    expect(uninstalled).to be_empty, "未導入: #{uninstalled.inspect}"
  end

  # 導入状況に応じて出入りする想定のモデルは、ガードと実態が一致していること。
  it "decidim-initiatives の導入有無とガードが一致する" do
    expect(Decidim::Ai::SpamDetection.resource_models.has_key?("Decidim::Initiative"))
      .to eq(Decidim.module_installed?("initiatives"))
  end
end
