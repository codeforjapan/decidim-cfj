# frozen_string_literal: true

require "rails_helper"

# 0.30 では _meeting_agenda.html.erb が参加者向けの decidim_sanitize_translated で
# アジェンダを描画しており、管理画面のエディタで入れた画像が落ちていた。cfj は deface で
# decidim_sanitize_editor_admin に差し替えて対処していた(PR #902)。
#
# 0.31 で上流が同じ設計を取り込んだため、その deface は 0.32 で不要になり削除した。
#   - AgendaItemPresenter が新設され、テンプレートが render_meeting_sanitize_field に置換
#   - safe_content_admin? == @meeting.official? で admin スクラバに分岐
#     (decidim-meetings/app/helpers/decidim/meetings/application_helper.rb)
#
# このスペックは移譲先の上流実装が期待どおりに動くことを見張る。落ちたら上流の
# サニタイズ経路が変わったということなので、deface の復活ではなく原因の特定から入ること。
#
# 押さえている点: アップロード画像は Decidim::Attributes::RichText#serialize_value が
# ActiveStorage の gid として保存するため、描画側が decidim_rich_text(BlobRenderer)を
# 通さないと Loofah が gid スキームの src を丸ごと落とす。official 判定と合わせて検証する。
describe "Meeting agenda item image", type: :system do
  include_context "with a component"
  let(:manifest_name) { "meetings" }

  let(:editor_image) { create(:editor_image, organization:) }
  let(:image_url) { editor_image.attached_uploader(:file).path }
  let(:stored_description) do
    Decidim::Attributes::RichText.new.send(
      :serialize_value,
      "<p>test</p><p><img src=\"#{image_url}\"></p>"
    )
  end

  before do
    agenda = create(:agenda, meeting:, visible: true)
    create(:agenda_item, agenda:, description: { en: stored_description })
    stub_geocoding_coordinates([meeting.latitude, meeting.longitude])
  end

  context "when the meeting is official" do
    let!(:meeting) { create(:meeting, :published, :official, component:) }

    it "resolves the uploaded image back to a working URL" do
      visit resource_locator(meeting).path

      within "[data-meeting-agenda]" do
        expect(page).to have_css("img[src*='/rails/active_storage/']")
      end
    end

    context "when the image comes from raw HTML instead of the upload button" do
      # decidim-cfj's editor also parses bare `<img>` tags that aren't
      # wrapped in the `<div class="editor-content-image" data-image="">`
      # the standard image extension produces (see app/packs/src/decidim/
      # cfj/editor/extensions/simple_image), which is what ends up stored
      # when someone pastes/types HTML with an <img> tag directly rather
      # than using the image button. BlobRenderer/AdminInputScrubber don't
      # care about that wrapper, but this pins down that behavior.
      let(:stored_description) do
        Decidim::Attributes::RichText.new.send(
          :serialize_value,
          "<p>test</p><img src=\"#{image_url}\" width=\"120\" height=\"80\">"
        )
      end

      it "still resolves the image and keeps its attributes" do
        visit resource_locator(meeting).path

        within "[data-meeting-agenda]" do
          expect(page).to have_css("img[src*='/rails/active_storage/'][width='120'][height='80']")
        end
      end
    end
  end

  context "when the meeting is not official" do
    let!(:meeting) { create(:meeting, :published, :not_official, component:) }

    it "keeps the stricter participant-facing sanitizer, which drops the image" do
      visit resource_locator(meeting).path

      within "[data-meeting-agenda]" do
        expect(page).to have_no_css("img")
      end
    end
  end
end
