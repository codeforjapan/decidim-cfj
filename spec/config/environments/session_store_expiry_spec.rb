# frozen_string_literal: true

require "rails_helper"

# config/environments/production.rb / development.rb の session_store
#
# セッションの有効期限は :build_middleware_stack の時点で確定する。環境設定ファイルは
# :load_environment_config で読まれ、config/initializers/decidim.rb が secrets から
# Decidim.config.expire_session_after を上書きする :load_config_initializers は
# その後に走る。そのため環境設定ファイルで Decidim.config.expire_session_after を
# 読むと、Decidim の既定値 30 分が渡り DECIDIM_EXPIRE_SESSION_AFTER が効かない。
#
# 本番で実際に起きていた。環境変数に 120 を入れても Devise の timeoutable だけが
# 120 分で、cookie と Redis のセッション TTL は 30 分のままだった。
#
# NOTE: 挙動そのものを spec で検証できない。config/environments/test.rb は
# session_store を設定せず、cache_store を使う経路に入らないため。
# 代わりに「secrets から読んでいること」を設定の不変条件として見張る。
# 挙動は development で DECIDIM_EXPIRE_SESSION_AFTER を変えて実測済み
# (30 -> expire_after 30 minutes / 120 -> 120 minutes)。
describe "session store expiry configuration" do
  # session_expire_after の算出から config.session_store の呼び出しまでをひとまとまりで見る。
  # コメント行は落とす。説明文に .minutes 等が出てくると検査が素通りするため。
  let(:session_store_lines) do
    %w(production development).to_h do |env|
      src = Rails.root.join("config/environments/#{env}.rb").read
      region = src[/session_expire_after =.*?config\.session_store\([^\n]*/m].to_s
      [env, region.lines.grep_v(/\A\s*#/).join]
    end
  end

  it "secrets から expire_session_after を引ける" do
    expect(Rails.application.secrets.decidim[:expire_session_after].to_s).to match(/\A\d+\z/)
  end

  it "Decidim.config は secrets の値を反映している" do
    expect(Decidim.config.expire_session_after)
      .to eq(Rails.application.secrets.decidim[:expire_session_after].to_i.minutes)
  end

  context "when configuring the session store" do
    # .minutes を落とすと Rack::Session は秒として解釈する。=120 が 120 秒になり、
    # 本 PR が防ごうとしたバグの悪化版になるので単位まで固定する。
    it "環境設定ファイルが secrets から分単位で expire_after を組み立てている" do
      session_store_lines.each do |env, source|
        expect(source).to match(/secrets\.decidim\[:expire_session_after\]\.to_i/),
                          "#{env}.rb が secrets から読んでいない"
        expect(source).to match(/\.minutes\b/),
                          "#{env}.rb が expire_after を分単位で渡していない（秒と解釈される）"
      end
    end

    # これを読むと :load_environment_config 時点の既定値 30 分が渡ってしまう。
    it "Decidim.config.expire_session_after を読んでいない" do
      session_store_lines.each do |env, line|
        expect(line).not_to include("Decidim.config.expire_session_after"),
                            "#{env}.rb の session_store が Decidim.config を読んでいる（初期化順の都合で必ず既定値になる）"
      end
    end
  end
end
