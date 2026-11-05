# frozen_string_literal: true

# PDF 出力が日本語 (漢字) で例外を投げ、アンケート確認メールが送信されない問題への対処。
#
# decidim の PDF 出力は Source Sans Pro を埋め込むが、同梱されているのは
# cyrillic / greek / latin / vietnamese のサブセットで CJK グリフを一切持たない。
# ファイル名がそのまま実態を表している。
#
#   decidim-core/app/packs/fonts/decidim/
#     source-sans-pro-v21-cyrillic_cyrillic-ext_greek_greek-ext_latin_latin-ext_vietnamese-700.ttf
#
# 本番コンテナでの実測 (0.30.9):
#   font_name=SourceSansPro-Bold num_glyphs=1462
#   'A' → Glyph  /  'あ' '年' '日' → いずれも InvalidGlyph
#
# HexaPDF は InvalidGlyph をエンコードする段階で MissingGlyphError を送出するため、
# 漢字が 1 文字でも含まれると PDF 生成ごと失敗する。
# Decidim::Surveys::SurveyConfirmationMailer は回答内容の PDF を添付するので
# (survey_confirmation_mailer.rb:30)、日本語のアンケートでは確認メールが届かない。
#
# 本番ログでの実害 (直近 24 時間):
#   Surveys::SurveyConfirmationMailer  完了 126 / 失敗 6  HexaPDF::MissingGlyphError
#   例) No glyph for "年" / "質" / "🌱" in font 'Source Sans Pro Bold' found.
#
# 対処は 2 点。
#
#   1. IPAex ゴシック (Debian: fonts-ipaexfont-gothic) に差し替える
#      単一ウェイトしか無いため regular と bold は同じ実体を使う。
#      見出しが太字にならないが、メールが届かないよりは良いと判断した。
#      HexaPDF 1.1.1 は TrueType コレクション (.ttc) を読めないため
#      fonts-noto-cjk は使えない。単体 TTF を配る IPAex を選んでいる。
#
#   2. グリフが無い文字は代替文字に置換して継続する
#      IPAex にも絵文字や一部の異体字 (𠮷 など) は無く、そこで再び全体が落ちる。
#      1 文字のために PDF 全体を落とさない方針は open_data の override と同じ。
#
# decidim 0.30.9 / 0.31.7 / 0.32.1 / develop のいずれも同一実装のため
# 上流追従では解消しない。
module DecidimCfjPdfCjkFontPatch
  # Dockerfile / CI で導入する fonts-ipaexfont-gothic の配置先 (Debian bookworm)。
  CJK_FONT_PATH = "/usr/share/fonts/opentype/ipaexfont-gothic/ipaexg.ttf"

  # グリフが無い文字の代替。先頭から順に、フォントが持っているものを使う。
  # 〓 (ゲタ記号) は活字が無いことを示す日本語の慣習的な代替表記。
  REPLACEMENT_CHARACTERS = %w(〓 ?).freeze

  class << self
    def font_available?
      return @font_available if defined?(@font_available)

      @font_available = File.exist?(CJK_FONT_PATH)
    end

    # HexaPDF の font.on_missing_glyph に渡す差し替え処理。
    #
    # InvalidGlyph をそのまま返しても TrueTypeWrapper#encode が
    # MissingGlyphError を送出するため意味がない (実測で確認済み)。
    # 実在するグリフを返して初めて継続できる。
    def replacement_glyph(character, font_wrapper)
      table = cmap_table(font_wrapper)
      replacement = REPLACEMENT_CHARACTERS.find { |char| table[char.ord].to_i.positive? } if table

      # 代替文字すら持たないフォントでは上流と同じ挙動 (例外) に戻す。
      return HexaPDF::Font::InvalidGlyph.new(font_wrapper, character) if replacement.nil?

      font_wrapper.decode_utf8(replacement).first
    end

    private

    # decode_utf8 は欠落時に on_missing_glyph を呼ぶため、代替文字の有無を
    # それで調べると無限再帰になる。cmap を直接引いて回避する。
    def cmap_table(font_wrapper)
      wrapped = font_wrapper.wrapped_font
      return nil unless wrapped.respond_to?(:[])

      wrapped[:cmap]&.preferred_table
    rescue StandardError
      nil
    end
  end

  private

  def font
    return super unless DecidimCfjPdfCjkFontPatch.font_available?

    @font ||= document.fonts.add(CJK_FONT_PATH)
  end

  def bold_font
    return super unless DecidimCfjPdfCjkFontPatch.font_available?

    @bold_font ||= document.fonts.add(CJK_FONT_PATH)
  end

  # フォントが無い環境では置換も行わない。
  # 上流フォントのまま置換だけ有効にすると、日本語が丸ごと 〓 に化けた PDF が
  # 「正常な成果物」として送信されてしまい、例外で気づけなくなるため。
  def composer
    return super unless DecidimCfjPdfCjkFontPatch.font_available?

    @composer ||= super.tap do |built|
      built.document.config["font.on_missing_glyph"] =
        ->(character, font_wrapper) { DecidimCfjPdfCjkFontPatch.replacement_glyph(character, font_wrapper) }
    end
  end
end

unless DecidimCfjPdfCjkFontPatch.font_available?
  Rails.logger.warn(
    "[pdf] CJK フォントが見つかりません。日本語を含む PDF 出力は失敗します: " \
    "#{DecidimCfjPdfCjkFontPatch::CJK_FONT_PATH} (fonts-ipaexfont-gothic)"
  )
end

Rails.application.config.to_prepare do
  # Decidim::Exporters::FormPDF (アンケート回答) の基底クラス。
  Decidim::Exporters::PDF.prepend(DecidimCfjPdfCjkFontPatch)
  # 基底クラスを継承せず同じ実装を複製しているため個別に当てる。
  Decidim::Conferences::ConferenceDiplomaPDF.prepend(DecidimCfjPdfCjkFontPatch)
end
