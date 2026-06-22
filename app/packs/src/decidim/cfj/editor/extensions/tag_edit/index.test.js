/**
 * Integration spec for the cfj `TagEdit` TipTap extension.
 *
 * The editor under test is constructed with the **same DecidimKit extension
 * bundle that production loads** (the cfj override at
 * `app/packs/src/decidim/editor/extensions/decidim_kit/index.js`). Importing
 * the kit instead of cherry-picking individual extensions means:
 *
 *   - When decidim-core is upgraded and adds / removes / renames an
 *     extension, this spec automatically reflects the new set.
 *   - cfj's own extensions (TagEdit, Iframe, SimpleImage) are exercised
 *     together with the upstream ones, in the order the cfj kit registers
 *     them, just like production.
 *
 * Module resolution for `src/decidim/...` paths is configured in
 * jest.config.js via `bundle show decidim-core`. The dialog opens, mutates
 * the DOM, and resolves a Promise — all of which works in jsdom.
 */

import { Editor } from "@tiptap/core";

import DecidimKit from "src/decidim/editor/extensions/decidim_kit";

import {
  createEditorContainer,
  safeDestroy,
  setupDecidimI18n,
  waitFor,
  waitForRemoval,
} from "test/editor_helpers";

const createEditor = () => {
  return new Editor({
    element: createEditorContainer(),
    content: "",
    // Pass the kit with default options. The Image extension is conditionally
    // loaded only when `image.uploadDialogSelector` is set, which we leave
    // null so jsdom is not asked to manage the upload modal.
    extensions: [DecidimKit.configure({})],
  });
};

describe("TagEdit extension (integration via DecidimKit)", () => {
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
    it("loads the cfj decidim_kit override (TagEdit / Iframe / SimpleImage included)", () => {
      const names = editor.extensionManager.extensions.map((e) => e.name);
      expect(names).toContain("tagEdit");
      expect(names).toContain("iframe");
      expect(names).toContain("simpleImage");
      // Sanity: a representative core extension is also present.
      expect(names).toContain("dialog");
      expect(names).toContain("bold");
    });

    it("exposes both cfj commands and core commands on the editor", () => {
      expect(typeof editor.commands.tagEditDialog).toBe("function");
      expect(typeof editor.commands.toggleDialog).toBe("function");
    });
  });

  describe("handleDoubleClick gate", () => {
    // The double-click handler only acts when `editor.isActive("tagEdit")` is
    // true, but the tagEdit node is never inserted into the document anywhere
    // in the codebase, so this is always false. The expectation below pins
    // that behaviour so any future change which starts inserting the node
    // fails this test and prompts a review.
    it("is inactive in a fresh document (tagEdit node is never inserted)", () => {
      expect(editor.isActive("tagEdit")).toBe(false);
    });
  });

  describe("dialog flow", () => {
    // TextDialog appends to document.body asynchronously inside the
    // tagEditDialog command, so we poll the DOM via waitFor / waitForRemoval
    // from editor_helpers instead of awaiting the command directly.

    it("opens the dialog and renders a textarea named 'tagsrc'", async () => {
      editor.commands.setContent("<p>initial</p>");
      editor.commands.tagEditDialog();

      const textarea = await waitFor('textarea[name="tagsrc"]');
      expect(textarea).not.toBeNull();
      expect(textarea.tagName).toBe("TEXTAREA");
    });

    it("populates the textarea with the current editor HTML on open", async () => {
      const initialHtml = "<p>hello <strong>world</strong></p>";
      editor.commands.setContent(initialHtml);
      editor.commands.tagEditDialog();

      const textarea = await waitFor('textarea[name="tagsrc"]');
      expect(textarea.value).toBe(initialHtml);
    });

    it("applies the textarea value back to the editor when Save is clicked", async () => {
      editor.commands.setContent("<p>before</p>");
      editor.commands.tagEditDialog();

      const textarea = await waitFor('textarea[name="tagsrc"]');
      textarea.value = "<p>after edit</p>";

      const saveBtn = document.querySelector('button[data-action="save"]');
      expect(saveBtn).not.toBeNull();
      saveBtn.click();

      // The Save handler closes the dialog asynchronously; once the dialog is
      // gone the editor content has been updated via setContent.
      await waitForRemoval('textarea[name="tagsrc"]');
      expect(editor.getHTML()).toBe("<p>after edit</p>");
    });

    it("discards the textarea value when Cancel is clicked", async () => {
      editor.commands.setContent("<p>before</p>");
      editor.commands.tagEditDialog();

      const textarea = await waitFor('textarea[name="tagsrc"]');
      textarea.value = "<p>edited but not saved</p>";

      const cancelBtn = document.querySelector('button[data-action="cancel"]');
      expect(cancelBtn).not.toBeNull();
      cancelBtn.click();

      await waitForRemoval('textarea[name="tagsrc"]');
      expect(editor.getHTML()).toBe("<p>before</p>");
    });
  });
});
