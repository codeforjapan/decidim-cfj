/**
 * Integration spec for the cfj `SimpleImage` TipTap extension.
 *
 * Two editor setups are exercised:
 *
 *   1. DecidimKit with `image: false` -- the core Image extension is NOT
 *      loaded, only SimpleImage handles `<img>`. This mirrors `basic` and
 *      `content` toolbar modes in production.
 *
 *   2. DecidimKit with the core Image extension enabled (full toolbar
 *      mode). Both Image and SimpleImage are present. Verifies that
 *      `<div data-image><img></div>` goes through Image (wrapper preserved)
 *      while bare `<img>` falls to SimpleImage.
 *
 * The kit composition is the same one production loads, so a future
 * decidim upgrade that changes the kit will be reflected here automatically.
 */

import { Editor } from "@tiptap/core";

import DecidimKit from "src/decidim/editor/extensions/decidim_kit";

import {
  createEditorContainer,
  mountUploadDialogStub,
  safeDestroy,
  setupDecidimI18n,
} from "test/editor_helpers";

describe("SimpleImage extension (integration via DecidimKit)", () => {
  beforeAll(() => {
    setupDecidimI18n();
  });

  describe("without the core Image extension (basic / content mode)", () => {
    let editor;

    beforeEach(() => {
      document.body.innerHTML = "";
      editor = new Editor({
        element: createEditorContainer(),
        content: "",
        extensions: [DecidimKit.configure({ image: false })],
      });
    });

    afterEach(() => safeDestroy(editor));

    it("loads bare <img> as a simpleImage node and preserves src", () => {
      editor.commands.setContent('<p><img src="https://example.com/a.png"></p>');
      expect(editor.getHTML()).toBe('<p><img src="https://example.com/a.png"></p>');
    });

    it("preserves alt and title on round-trip", () => {
      editor.commands.setContent(
        '<p><img src="https://example.com/a.png" alt="alt text" title="t"></p>'
      );
      const html = editor.getHTML();
      expect(html).toContain('src="https://example.com/a.png"');
      expect(html).toContain('alt="alt text"');
      expect(html).toContain('title="t"');
    });

    it("drops data: URIs (parseHTML excludes them)", () => {
      editor.commands.setContent('<p><img src="data:image/png;base64,AAA"></p>');
      expect(editor.getHTML()).not.toContain("<img");
    });

    it("rescues the inner <img> of <div data-image> even though Image is absent (wrapper is dropped)", () => {
      // No Image extension to claim the wrapper; SimpleImage catches the
      // inner <img> so the picture is not silently lost. The wrapper itself
      // has no matching extension and gets stripped.
      editor.commands.setContent(
        '<div data-image><img src="https://example.com/wrapped.png" alt="w"></div>'
      );
      const html = editor.getHTML();
      expect(html).toContain('src="https://example.com/wrapped.png"');
      expect(html).not.toContain("data-image");
    });
  });

  describe("with the core Image extension loaded (full mode)", () => {
    let editor;
    let uploadDialogSelector;

    beforeEach(() => {
      document.body.innerHTML = "";
      uploadDialogSelector = mountUploadDialogStub();
      editor = new Editor({
        element: createEditorContainer(),
        content: "",
        extensions: [
          DecidimKit.configure({
            image: {
              uploadDialogSelector,
              uploadImagesPath: "/editor_images",
              contentTypes: /^image\//,
            },
          }),
        ],
      });
    });

    afterEach(() => safeDestroy(editor));

    it("loads both Image and SimpleImage extensions", () => {
      const names = editor.extensionManager.extensions.map((e) => e.name);
      expect(names).toContain("image");
      expect(names).toContain("simpleImage");
    });

    it("routes wrapped <img> through the core Image extension (wrapper preserved)", () => {
      const wrapped = '<div data-image><img src="https://example.com/w.png" alt="w"></div>';
      editor.commands.setContent(wrapped);
      const html = editor.getHTML();
      expect(html).toContain('data-image=""');
      expect(html).toContain('class="editor-content-image"');
      expect(html).toContain('src="https://example.com/w.png"');
      expect(html).toContain('alt="w"');
    });

    it("routes bare <img> through SimpleImage (no wrapper)", () => {
      editor.commands.setContent('<p><img src="https://example.com/bare.png" alt="b"></p>');
      const html = editor.getHTML();
      expect(html).toContain('src="https://example.com/bare.png"');
      expect(html).toContain('alt="b"');
      expect(html).not.toContain("data-image");
      expect(html).not.toContain("editor-content-image");
    });

    it("preserves both forms in a mixed document", () => {
      const mixed =
        '<div data-image><img src="https://example.com/wrap.png"></div>' +
        '<p><img src="https://example.com/bare.png"></p>';
      editor.commands.setContent(mixed);
      const html = editor.getHTML();
      // Both source URLs survive.
      expect(html).toContain('src="https://example.com/wrap.png"');
      expect(html).toContain('src="https://example.com/bare.png"');
      // The wrapped one keeps its wrapper marker; the bare one does not.
      expect((html.match(/data-image/g) || []).length).toBe(1);
    });
  });
});
