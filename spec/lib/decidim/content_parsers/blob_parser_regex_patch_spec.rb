# frozen_string_literal: true

require "rails_helper"

# Pins the regression fixed by config/initializers/blob_parser_regex_patch.rb.
#
# Without the patch, BLOB_REGEX's host part `((?!/rails).)+` matches greedily
# across HTML, swallowing any external image markup and the wrapper opening
# tag that sits between an external <img> and a blob <img>. With the patch
# the regex only consumes characters that can legitimately appear inside a
# URL literal, so each blob URL is matched in isolation.
#
# The cases below intentionally exercise the regex via `gsub` and via the
# real parser, so a future change that drops the patch (or reverts to the
# greedy upstream regex) trips at least one expectation.
describe "Decidim::ContentParsers::BlobParser::BLOB_REGEX (greedy match fix)" do
  let(:regex) { Decidim::ContentParsers::BlobParser::BLOB_REGEX }

  describe "the constant alone" do
    let(:external_then_blob) do
      <<~HTML.delete("\n")
        <p><img src="https://sample.photos/id/237/200/300"></p>
        <div class="editor-content-image" data-image=""><img src="http://example.test/rails/active_storage/disk/SOMEKEY/old-admin-form.png" alt="w" width="648"></div>
      HTML
    end

    it "does not span across the external <img> when followed by a blob <img>" do
      match = external_then_blob.match(regex)
      expect(match).not_to be_nil
      expect(match[0]).not_to include("sample.photos")
      expect(match[0]).not_to include("<")
      expect(match[0]).not_to include('"')
    end

    it "matches exactly the blob URL substring" do
      expect(external_then_blob[regex]).to eq(
        "http://example.test/rails/active_storage/disk/SOMEKEY/old-admin-form.png"
      )
    end

    it "leaves intervening HTML intact when used with gsub replacement" do
      replaced = external_then_blob.gsub(regex) { "[BLOB]" }

      expect(replaced).to include('<img src="https://sample.photos/id/237/200/300">')
      expect(replaced).to include('<div class="editor-content-image" data-image="">')
      expect(replaced).to include('<img src="[BLOB]" alt="w" width="648">')
      expect(replaced).to include("</div>")
      expect(replaced.scan("[BLOB]").size).to eq(1)
    end

    it "still matches a single blob URL with no surrounding content" do
      url = "http://example.test/rails/active_storage/disk/ABC/file.png"
      expect(url[regex]).to eq(url)
    end

    it "matches a representations URL with variation key" do
      url = "http://example.test/rails/active_storage/representations/redirect/SIG/VARIATION/file.png"
      expect(url[regex]).to eq(url)
    end

    it "does not match content with no blob URL" do
      html = '<p>Plain text with <img src="https://example.com/x.png"></p>'
      expect(html[regex]).to be_nil
    end
  end

  describe "via the real parser (`rewrite`)" do
    # The real parser delegates the lookup to ActiveStorage::Blob.find_signed,
    # which is exercised in spec/lib/decidim/content_parsers/blob_parser_spec.rb.
    # Here we only care that the surrounding HTML survives the gsub — the
    # blob lookup itself may succeed or fall through to `next match`; in
    # either case the assertions below are valid because they describe what
    # must NOT happen (markup loss outside the URL literal).
    let(:external_url) { "https://sample.photos/id/237/200/300" }
    let(:blob_url) { "/rails/active_storage/disk/SOMEKEY/old-admin-form.png" }

    let(:content) do
      <<~HTML.delete("\n")
        <p>test</p>
        <p>aaaaa</p>
        <p></p>
        <p><img src="#{external_url}"></p>
        <div class="editor-content-image" data-image=""><img src="#{blob_url}" alt="w" width="648"></div>
      HTML
    end

    it "preserves the external <img>, the wrapper opening tag, and surrounding HTML" do
      rewritten = Decidim::ContentParsers::BlobParser.new(content, {}).rewrite

      expect(rewritten).to include("<p>test</p>")
      expect(rewritten).to include("<p>aaaaa</p>")
      expect(rewritten).to include(%(<img src="#{external_url}">))
      expect(rewritten).to include('<div class="editor-content-image" data-image="">')
      expect(rewritten).to include('alt="w" width="648"')
    end

    it "does not leave a stray </div> from a destroyed wrapper opening tag" do
      rewritten = Decidim::ContentParsers::BlobParser.new(content, {}).rewrite

      open_divs = rewritten.scan(/<div\b/).size
      close_divs = rewritten.scan(%r{</div>}).size
      expect(open_divs).to eq(close_divs)
    end
  end
end
