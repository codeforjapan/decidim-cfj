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

// Decidim's editor i18n is normally provided via
// `window.Decidim.config.get("messages")`. The dialog and a few extensions
// read keys lazily, so seeding the minimum surface here keeps the flow alive
// without pulling in the full locale fixtures.
const setupDecidimI18n = () => {
  const editorMessages = {
    inputDialog: {
      close: "Close",
      "buttons.cancel": "Cancel",
      "buttons.save": "Save",
    },
  };
  window.Decidim = {
    config: {
      get: (key) => ({ messages: { editor: editorMessages } }[key]),
    },
  };
};

const createEditor = () => {
  const element = document.createElement("div");
  document.body.append(element);
  return new Editor({
    element,
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

  afterEach(() => {
    // Some decidim-core extensions (e.g. Link's bubble menu) attach DOM
    // positioning logic in onCreate that does not initialise cleanly in jsdom,
    // which then causes their onDestroy to throw a null reference at editor
    // teardown. The test bodies themselves run fine; suppress the cleanup
    // error so the test result reflects the actual behaviour under test.
    try {
      editor.destroy();
    } catch (_e) {
      /* ignore jsdom-only destroy errors */
    }
  });

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
    // The dialog is mounted asynchronously (TextDialog appends to document.body
    // inside the tagEditDialog command). The command itself is fire-and-forget
    // from the editor.commands perspective, so we poll the DOM instead of
    // awaiting the promise directly.
    const waitFor = async (selector, timeoutMs = 500) => {
      const start = Date.now();
      while (Date.now() - start < timeoutMs) {
        const el = document.querySelector(selector);
        if (el) return el;
        await new Promise((resolve) => setTimeout(resolve, 10));
      }
      throw new Error(`waitFor: ${selector} did not appear within ${timeoutMs}ms`);
    };

    const waitForRemoval = async (selector, timeoutMs = 500) => {
      const start = Date.now();
      while (Date.now() - start < timeoutMs) {
        if (!document.querySelector(selector)) return;
        await new Promise((resolve) => setTimeout(resolve, 10));
      }
      throw new Error(`waitForRemoval: ${selector} still present after ${timeoutMs}ms`);
    };

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
