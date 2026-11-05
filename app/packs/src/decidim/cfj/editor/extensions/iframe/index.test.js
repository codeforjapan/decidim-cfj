/**
 * Integration spec for the cfj `Iframe` TipTap extension.
 *
 * Built on the same DecidimKit composition production loads (cfj's override
 * at `app/packs/src/decidim/editor/extensions/decidim_kit/index.js`). The
 * kit's `image` option is left default (Image extension is not registered),
 * so no upload-modal stub is needed; the Iframe extension is what we are
 * exercising here.
 *
 * Running through the kit means a future decidim upgrade that changes the
 * extension bundle or alters how Iframe interacts with siblings (Link,
 * Bold, Dialog, …) will be reflected here automatically.
 */

import { Editor } from "@tiptap/core";

import DecidimKit from "src/decidim/editor/extensions/decidim_kit";

import {
  createEditorContainer,
  safeDestroy,
  setupDecidimI18n,
} from "test/editor_helpers";

const createEditor = () => {
  return new Editor({
    element: createEditorContainer(),
    content: "",
    extensions: [DecidimKit.configure({})],
  });
};

describe("Iframe extension (integration via DecidimKit)", () => {
  let editor;

  beforeAll(() => {
    setupDecidimI18n();
  });

  beforeEach(() => {
    document.body.innerHTML = "";
    editor = createEditor();
  });

  afterEach(() => safeDestroy(editor));

  describe("kit composition", () => {
    it("loads the iframe extension via the cfj decidim_kit override", () => {
      const names = editor.extensionManager.extensions.map((e) => e.name);
      expect(names).toContain("iframe");
    });
  });

  describe("renderHTML wrapper", () => {
    it("wraps the iframe inside a div.iframe-wrapper", () => {
      editor.commands.setContent('<iframe src="https://example.com/embed/x"></iframe>');
      expect(editor.getHTML()).toMatchHtml(`
        <div class="iframe-wrapper">
          <iframe src="https://example.com/embed/x" frameborder="0" allowfullscreen="true"></iframe>
        </div>
      `);
    });
  });

  describe("isAllowedDomain gate", () => {
    it("preserves the src for HTTPS iframes", () => {
      editor.commands.setContent('<iframe src="https://example.com/embed/x"></iframe>');
      expect(editor.getHTML()).toContain('src="https://example.com/embed/x"');
    });

    it("strips the src for HTTP iframes (still renders the iframe element)", () => {
      editor.commands.setContent('<iframe src="http://example.com/embed/x"></iframe>');
      const html = editor.getHTML();
      expect(html).toContain("<iframe");
      // The iframe must have no src attribute at all — not just a missing URL.
      expect(html).not.toMatch(/<iframe[^>]*\ssrc=/);
    });

    it("strips the src for protocol-relative URLs", () => {
      editor.commands.setContent('<iframe src="//example.com/embed/x"></iframe>');
      const html = editor.getHTML();
      expect(html).toContain("<iframe");
      expect(html).not.toMatch(/<iframe[^>]*\ssrc=/);
    });
  });

  describe("declared attributes", () => {
    it("round-trips width, height and title for an allowed src", () => {
      editor.commands.setContent(
        '<iframe src="https://example.com/" width="640" height="360" title="demo"></iframe>'
      );
      const html = editor.getHTML();
      expect(html).toContain('width="640"');
      expect(html).toContain('height="360"');
      expect(html).toContain('title="demo"');
    });
  });
});
