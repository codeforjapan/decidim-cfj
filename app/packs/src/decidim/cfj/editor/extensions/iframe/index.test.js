/**
 * Specification for the cfj `Iframe` TipTap extension.
 *
 * Real test that exercises:
 *   - cfj source under `app/packs/src/decidim/cfj/editor/extensions/iframe`
 *   - @tiptap/core + the minimum extensions to materialise an Editor
 *   - the isAllowedDomain (HTTPS-only) gate, exercised via setContent
 *
 * Run with `yarn test`.
 */

import { Editor } from "@tiptap/core";
import Document from "@tiptap/extension-document";
import Paragraph from "@tiptap/extension-paragraph";
import Text from "@tiptap/extension-text";

import Iframe from "src/decidim/cfj/editor/extensions/iframe";

const createEditor = () => {
  const element = document.createElement("div");
  document.body.append(element);
  return new Editor({
    element,
    content: "",
    extensions: [Document, Paragraph, Text, Iframe],
  });
};

describe("Iframe extension", () => {
  let editor;

  beforeEach(() => {
    document.body.innerHTML = "";
    editor = createEditor();
  });

  afterEach(() => {
    editor.destroy();
  });

  describe("renderHTML wrapper", () => {
    it("wraps the iframe inside a div.iframe-wrapper", () => {
      editor.commands.setContent('<iframe src="https://example.com/embed/x"></iframe>');
      const html = editor.getHTML();
      expect(html).toContain('class="iframe-wrapper"');
      expect(html).toContain("<iframe");
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
      expect(html).not.toContain('src="http://example.com/embed/x"');
    });

    it("strips the src for protocol-relative URLs", () => {
      editor.commands.setContent('<iframe src="//example.com/embed/x"></iframe>');
      const html = editor.getHTML();
      expect(html).toContain("<iframe");
      expect(html).not.toContain('src="//example.com/embed/x"');
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
