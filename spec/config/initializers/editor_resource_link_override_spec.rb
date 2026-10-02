# frozen_string_literal: true

require "rails_helper"

# config/initializers/editor_resource_link_override.rb
#
# 保存側の ResourceParser は href の中まで URL を gid に書き換える。tiptap の
# Link 拡張は許可外スキームの href を持つリンクを破棄するため、放置すると
# 編集画面を開いて保存しただけでリンクが消える。ここでは「エディタに渡る前に
# 属性内の gid を絶対 URL へ戻す」ことと、「保存で元の gid に戻る」ことを見る。
describe "Editor resource link override" do
  subject(:rewrite) { DecidimCfjEditorResourceLink.rewrite(html) }

  let(:organization) { create(:organization) }
  let(:participatory_process) { create(:participatory_process, organization:) }
  let(:component) { create(:proposal_component, participatory_space: participatory_process) }
  let(:proposal) { create(:proposal, component:) }
  let(:proposal_gid) { proposal.to_global_id.to_s }
  let(:proposal_url) { Decidim::ResourceLocatorPresenter.new(proposal).url }

  describe "href に入った gid" do
    let(:html) { %(<p><a href="#{proposal_gid}">詳しくはこちら</a></p>) }

    it "絶対 URL に戻す" do
      expect(rewrite).to include(%(href="#{proposal_url}"))
      expect(rewrite).not_to include("gid://")
    end

    # 相対パスだと保存側の URL_REGEX_SCHEME にマッチせず gid に戻らないため、
    # 生パスのまま保存されて slug 変更耐性を失う。
    it "スキーム付きの絶対 URL であること" do
      expect(rewrite).to match(%r{href="https?://})
    end
  end

  describe "本文テキスト中の gid" do
    let(:html) { %(<p>参考 #{proposal_gid} です</p>) }

    # ここを変換すると display_mention が <a> を生やし、管理者が編集する対象が
    # 変わってしまう。直したいのは href に入った gid だけ。
    it "触らない" do
      expect(rewrite).to eq(html)
    end
  end

  describe "解決できない gid" do
    let(:html) { %(<a href="gid://decidim-app/Decidim::Proposals::Proposal/999999">x</a>) }

    # href を空にするとリンクごと消える。戻せないものは元のまま残す。
    it "元の gid を残す" do
      expect(rewrite).to include("gid://decidim-app/Decidim::Proposals::Proposal/999999")
    end
  end

  describe "gid を含まない本文" do
    let(:html) { %(<p>ふつうの<a href="https://example.com">リンク</a></p>) }

    # cast_value は属性読み出しのたびに走るため、Nokogiri に入る前に弾く。
    it "そのまま返す" do
      expect(rewrite).to equal(html)
    end
  end

  describe "複数のリソース種別" do
    let(:meetings_component) { create(:meeting_component, participatory_space: participatory_process) }
    let(:meeting) { create(:meeting, component: meetings_component) }
    let(:html) do
      %(<p><a href="#{proposal_gid}">p</a><a href="#{meeting.to_global_id}">m</a></p>)
    end

    # 対象を提案だけに絞ると「提案リンクは直るが会議リンクは消え続ける」ことになる。
    it "提案も会議もまとめて戻す" do
      expect(rewrite).to include(Decidim::ResourceLocatorPresenter.new(proposal).url)
      expect(rewrite).to include(Decidim::ResourceLocatorPresenter.new(meeting).url)
      expect(rewrite).not_to include("gid://")
    end
  end

  describe "保存との往復" do
    let(:html) { %(<p><a href="#{proposal_gid}">a</a></p>) }

    # gid → URL → 保存 → gid が閉じないと、保存のたびに形式が変わってしまう。
    it "元の gid に戻る" do
      saved = Decidim::ContentProcessor.parse(rewrite, { current_organization: organization }).rewrite

      expect(saved).to eq(html)
    end
  end

  describe "フォーム経由での適用" do
    let(:form_class) do
      Class.new(Decidim::Form) do
        include Decidim::TranslatableAttributes

        translatable_attribute :body, Decidim::Attributes::RichText
      end
    end
    let(:html) { %(<p><a href="#{proposal_gid}">a</a></p>) }

    # form_builder#editor が出力する hidden_field はこのゲッターを通る。
    # 多言語フィールドではロケールごとの String に対して個別に走る。
    it "ロケールごとに変換される" do
      form = form_class.new(body: { "ja" => html, "en" => html })

      expect(form.body_ja).to include(proposal_url)
      expect(form.body_en).to include(proposal_url)
      expect(form.body_ja).not_to include("gid://")
    end

    describe "BlobRendererでのBlob GID対応との共存" do
      let(:blob) do
        ActiveStorage::Blob.create_and_upload!(
          io: File.open(Decidim::Dev.asset("city.jpeg")),
          filename: "city.jpeg",
          content_type: "image/jpeg"
        )
      end
      let(:html) { %(<img src="#{blob.to_global_id}">) }

      it "Blob GID も従来通り添付ファイルURLに変換される" do
        form = form_class.new(body: { "ja" => html })

        expect(form.body_ja).not_to include("gid://")
        expect(form.body_ja).to match(%r{/rails/active_storage/})
      end
    end
  end
end
