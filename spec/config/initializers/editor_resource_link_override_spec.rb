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

  describe "gid の後ろに続く部分" do
    # ResourceParser stops the gid at the id, so a query or fragment can follow it.
    %w(?order=random #comment_5 /versions/3).each do |suffix|
      describe suffix do
        let(:html) { %(<a href="#{proposal_gid}#{suffix}">x</a>) }

        it "残したまま URL に戻す" do
          expect(rewrite).to include(%(href="#{proposal_url}#{suffix}"))
        end
      end
    end
  end

  describe "公開されていないリソースの gid" do
    let(:html) { %(<a href="#{target.to_global_id}">x</a>) }
    let(:target) { create(:proposal, :hidden, component:) }

    # tiptap drops a gid href, so saving the form would delete the link.
    it "エディタ向けには URL に戻す" do
      expect(rewrite).to include(%(href="#{Decidim::ResourceLocatorPresenter.new(target).url}"))
    end

    describe "公開画面向け" do
      subject(:rewrite) { DecidimCfjEditorResourceLink.rewrite(html, public_only: true) }

      let(:meetings_component) { create(:meeting_component, participatory_space: participatory_process) }

      # A hand-typed gid must not reveal URLs the reader cannot see.
      describe "下書きの提案" do
        let(:target) { create(:proposal, :draft, component:) }

        it "解決せず gid を残す" do
          expect(rewrite).to eq(html)
        end
      end

      describe "非表示にされた提案" do
        it "解決せず gid を残す" do
          expect(rewrite).to eq(html)
        end
      end

      describe "非公開の会議" do
        let(:target) { create(:meeting, :published, component: meetings_component, private_meeting: true, transparent: false) }

        it "解決せず gid を残す" do
          expect(rewrite).to eq(html)
        end
      end

      describe "未公開コンポーネントの提案" do
        let(:target) { create(:proposal, component: create(:proposal_component, :unpublished, participatory_space: participatory_process)) }

        it "解決せず gid を残す" do
          expect(rewrite).to eq(html)
        end
      end

      describe "非公開スペースの提案" do
        let(:private_process) { create(:participatory_process, organization:, private_space: true) }
        let(:target) { create(:proposal, component: create(:proposal_component, participatory_space: private_process)) }

        it "解決せず gid を残す" do
          expect(rewrite).to eq(html)
        end
      end

      describe "提案・会議以外" do
        let(:target) { create(:user, organization:) }

        # Only types ResourceParser produces are looked up; others never hit the DB.
        it "DB を引かずに gid を残す" do
          allow(GlobalID::Locator).to receive(:locate).and_call_original

          expect(rewrite).to eq(html)
          expect(GlobalID::Locator).not_to have_received(:locate)
        end
      end
    end
  end

  describe "提案・会議以外の gid" do
    let(:user) { create(:user, organization:) }
    let(:html) { %(<a href="#{user.to_global_id}">x</a>) }

    # The editor does not narrow types; anything with a URL is resolved.
    it "エディタ向けには解決を試みる" do
      allow(GlobalID::Locator).to receive(:locate).and_call_original

      rewrite

      expect(GlobalID::Locator).to have_received(:locate)
    end
  end

  describe "属性値の一部に含まれる gid" do
    let(:html) { %(<a href="mailto:?body=#{proposal_gid}">x</a>) }

    # ResourceParser also turns a URL in the middle of an attribute into a gid.
    it "その部分だけ URL に戻す" do
      expect(rewrite).to include(%(href="mailto:?body=#{proposal_url}"))
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
    let(:meeting) { create(:meeting, :published, component: meetings_component) }
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
