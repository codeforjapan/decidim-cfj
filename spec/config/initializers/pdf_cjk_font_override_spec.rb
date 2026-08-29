# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Decidim::Exporters::PDF CJK font override" do
  # 実際に PDF を書き出して判定する。上流フォントでは書き出し時の
  # エンコード段階で MissingGlyphError になるため、ここを通れることが要件そのもの。
  let(:exporter_class) do
    Class.new(Decidim::Exporters::PDF) do
      attr_accessor :sample

      def add_data!
        composer.text(sample, style: :h1)
      end

      def styles
        { h1: { font: bold_font, font_size: 18 } }
      end
    end
  end

  def render(text)
    exporter = exporter_class.new([], nil)
    exporter.sample = text
    exporter.export.read
  end

  it "applies the override to both PDF generators" do
    [Decidim::Exporters::PDF, Decidim::Conferences::ConferenceDiplomaPDF].each do |klass|
      expect(klass.ancestors).to include(DecidimCfjPdfCjkFontPatch),
                                 "#{klass} に override が適用されていない"
    end
  end

  it "uses the CJK font instead of the upstream latin-only font" do
    expect(File).to exist(DecidimCfjPdfCjkFontPatch::CJK_FONT_PATH)

    exporter = exporter_class.new([], nil)
    expect(exporter.send(:font).wrapped_font.font_name).to match(/IPAex/i)
    expect(exporter.send(:bold_font).wrapped_font.font_name).to match(/IPAex/i)
  end

  # 上流フォント (Source Sans Pro のラテンサブセット) では全て失敗するケース。
  # 漢字は本番で実際にアンケート確認メールを止めていた。
  #
  # 「例外が出ないこと」だけでは不十分。置換ガードが効いているため、
  # フォントが上流のままでも日本語が丸ごと 〓 に化けて "成功" してしまう。
  # 置換が一度も呼ばれないことまで確認して初めて、正しく描画されたと言える。
  [
    ["漢字", "2026年8月の回答"],
    ["ひらがな・カタカナ", "こんにちは カタカナ"],
    ["全角記号", "（株）①〜※"],
    ["ラテンとの混在", "Q1: 好きな色は?"]
  ].each do |label, text|
    it "renders #{label} with real glyphs" do
      expect(DecidimCfjPdfCjkFontPatch).not_to receive(:replacement_glyph)

      expect { render(text) }.not_to raise_error
    end
  end

  # IPAex にも無い文字。ここで落ちると結局メールが送れないため、
  # 代替文字に置換して PDF 生成を継続する。
  [
    ["絵文字を含む", "回答: 環境🌱について"],
    ["サロゲートペアの異体字", "𠮷野家"]
  ].each do |label, text|
    it "substitutes a replacement glyph for #{label}" do
      expect(DecidimCfjPdfCjkFontPatch).to receive(:replacement_glyph).at_least(:once).and_call_original

      expect { render(text) }.not_to raise_error
    end
  end

  describe ".replacement_glyph" do
    let(:font_wrapper) do
      exporter = exporter_class.new([], nil)
      exporter.send(:font)
    end

    it "returns a real glyph so that HexaPDF can encode it" do
      glyph = described_class_module.replacement_glyph("🌱", font_wrapper)

      expect(glyph).not_to be_a(HexaPDF::Font::InvalidGlyph)
      expect { font_wrapper.encode(glyph) }.not_to raise_error
    end

    it "falls back to the upstream behaviour when the font has no replacement character" do
      table = font_wrapper.wrapped_font[:cmap].preferred_table
      allow(table).to receive(:[]).and_return(nil)

      glyph = described_class_module.replacement_glyph("🌱", font_wrapper)

      expect(glyph).to be_a(HexaPDF::Font::InvalidGlyph)
    end
  end

  # フォント未導入の環境では置換も無効化し、上流と同じ挙動 (例外) に戻す。
  # 日本語が丸ごと 〓 に化けた PDF を「成功」として送ってしまわないため。
  context "when the CJK font is not installed" do
    before do
      allow(DecidimCfjPdfCjkFontPatch).to receive(:font_available?).and_return(false)
    end

    it "keeps the upstream font" do
      exporter = exporter_class.new([], nil)

      expect(exporter.send(:font).wrapped_font.font_name).to match(/SourceSansPro/i)
    end

    it "does not install the missing glyph handler" do
      exporter = exporter_class.new([], nil)
      handler = exporter.send(:composer).document.config["font.on_missing_glyph"]

      expect(handler).to eq(HexaPDF::DefaultDocumentConfiguration["font.on_missing_glyph"])
    end
  end

  # ここまでは override 単体の検証。以下は実際に本番で使われる経路
  # (SurveyConfirmationMailer が添付する PDF) を実データで通す。
  # engine.rb:64 が QuestionnaireUserAnswers.for(...) の戻り値をそのまま
  # FormPDF に渡すため、同じ形の collection を組み立てている。
  describe "Decidim::Exporters::FormPDF with real records" do
    let(:organization) { create(:organization) }
    let(:user) { create(:user, :confirmed, organization:) }
    let(:participatory_process) { create(:participatory_process, organization:) }
    let(:questionnaire) do
      create(:questionnaire, questionnaire_for: participatory_process, title: { ja: "市民アンケート2026", en: "Survey" })
    end
    let(:question) do
      create(:questionnaire_question, questionnaire:, body: { ja: "好きな季節は？", en: "Season?" })
    end
    let(:collection) { Decidim::Forms::QuestionnaireUserAnswers.for(questionnaire) }

    before { create(:answer, questionnaire:, question:, user:, body:) }

    def export
      Decidim::Exporters::FormPDF.new(collection, Decidim::Forms::UserAnswersSerializer).export.read
    end

    context "when the answer is written in japanese" do
      let(:body) { "2026年8月に回答しました。質問1への回答です。" }

      it "exports a pdf" do
        expect(collection).to be_present
        expect(export.byteslice(0, 5)).to eq("%PDF-")
      end
    end

    context "when the answer contains an emoji" do
      let(:body) { "回答: 環境🌱について" }

      it "exports a pdf" do
        expect(export.byteslice(0, 5)).to eq("%PDF-")
      end
    end
  end

  def described_class_module = DecidimCfjPdfCjkFontPatch
end
