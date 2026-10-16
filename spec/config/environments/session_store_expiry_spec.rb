# frozen_string_literal: true

require "rails_helper"

# 0.30 では config/initializers/decidim.rb が secrets から
# Decidim.config.expire_session_after を上書きしており、それが環境設定ファイルより
# 後に走るため DECIDIM_EXPIRE_SESSION_AFTER が効かなかった (#923)。
# 0.31 は既定値ブロックが Decidim::Env を遅延評価で読むので同じ問題は起きないが、
# 環境変数が届かなくなる退行を見張っておく。
describe "session store expiry configuration" do
  it "DECIDIM_EXPIRE_SESSION_AFTER が Decidim.config に反映される" do
    expect(Decidim.config.expire_session_after)
      .to eq(Decidim::Env.new("DECIDIM_EXPIRE_SESSION_AFTER", "30").to_i.minutes)
  end

  it "環境設定ファイルが expire_after を Decidim.config から渡している" do
    %w(production development).each do |env|
      line = Rails.root.join("config/environments/#{env}.rb").readlines
                  .find { |l| l.include?("config.session_store(") }

      expect(line).to match(/expire_after: Decidim\.config\.expire_session_after/),
                      "#{env}.rb が expire_after を Decidim.config から渡していない"
    end
  end
end
