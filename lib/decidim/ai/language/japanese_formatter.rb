# frozen_string_literal: true

module Decidim
  module Ai
    module Language
      class JapaneseFormatter < Formatter
        def cleanup(text)
          s = super
          normalize_for_classifier(s)
        end

        private

        # content を ASCII トークン列に正規化する
        # - 英数字は従来通り単語として残す
        # - 非ASCIIは codepoint を uXXXX にして 1文字=1トークンで追加
        #
        # 例: "しね" => "u3057 u306d"
        #     "buy 安い pills" => "buy pills u5b89 u3044"
        def normalize_for_classifier(content)
          s = content.to_s
          tokens = []

          # ASCIIの単語（英数字+_）はそのまま（英語性能を落としにくい）
          tokens.concat(s.scan(/[A-Za-z0-9_]+/))

          # 非ASCIIは codepoint を ASCIIトークン化
          s.each_codepoint do |cp|
            next if cp < 128

            tokens << "u#{cp.to_s(16)}"
          end

          # 何も残らないと Bayes が no-op になりがちなので、空ならダミーを返す
          tokens.empty? ? "u0" : tokens.join(" ")
        end
      end
    end
  end
end
