# frozen_string_literal: true

require "rails_helper"

# 環境設定ファイルで Decidim.config.expire_session_after を読むと、secrets からの上書き
# (config/initializers/decidim.rb) より前に評価されるため常に既定値 30 分になる。本番で発生した。
# test.rb は session_store を設定せず挙動を再現できないので、設定の不変条件として見張る。
describe "session store expiry configuration" do
  # コメント行は落とす。説明文の .minutes を拾うと検査が素通りするため。
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
    # .minutes を落とすと Rack::Session は秒として解釈する (=120 が 120 秒)。
    it "環境設定ファイルが secrets から分単位で expire_after を組み立てている" do
      session_store_lines.each do |env, source|
        expect(source).to match(/secrets\.decidim\[:expire_session_after\]\.to_i/),
                          "#{env}.rb が secrets から読んでいない"
        expect(source).to match(/\.minutes\b/),
                          "#{env}.rb が expire_after を分単位で渡していない（秒と解釈される）"
      end
    end

    it "Decidim.config.expire_session_after を読んでいない" do
      session_store_lines.each do |env, line|
        expect(line).not_to include("Decidim.config.expire_session_after"),
                            "#{env}.rb の session_store が Decidim.config を読んでいる（初期化順の都合で必ず既定値になる）"
      end
    end
  end
end
