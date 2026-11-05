# frozen_string_literal: true

require "rails_helper"

# Covers app/overrides/decidim/meetings/meetings/_meeting_agenda/*.deface.
#
# decidim_sanitize_admin never runs content through decidim_rich_text
# (BlobRenderer), so an agenda item description containing an uploaded
# image is stored as an ActiveStorage blob gid, not as a plain URL, by
# Decidim::Attributes::RichText#serialize_value when the admin form is
# saved. decidim_sanitize_admin left that gid in the `src` attribute,
# and Loofah then dropped the whole attribute because `gid` is not an
# allowed URI protocol. decidim_sanitize_editor_admin resolves the gid
# back into a working URL (and also runs the content through
# IframeDisabler, keeping any embedded iframe gated behind data-consent)
# before sanitizing.
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
