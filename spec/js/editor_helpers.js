// Shared helpers for editor extension specs.
//
// All TipTap-based editor specs import from here so that:
//   - the i18n surface mirrors what production injects via
//     `window.Decidim.config.get("messages")`, reusing decidim-core's own
//     `editor_messages` test fixture (it lives in the gem so it tracks the
//     installed Decidim version)
//   - the upload-modal DOM stub also reuses decidim-core's `upload_templates`
//     fixture, so a future change to that template is automatically picked up
//   - common cleanup / DOM polling utilities are not duplicated across specs

import editorMessages from "src/decidim/editor/test/fixtures/editor_messages";
import uploadTemplates from "src/decidim/editor/test/fixtures/upload_templates";

/**
 * Seeds `window.Decidim.config.get("messages")` with decidim-core's full
 * editor i18n fixture. Idempotent across calls. Use in `beforeAll`.
 */
export const setupDecidimI18n = () => {
  window.Decidim = {
    config: {
      get: (key) => ({ messages: { editor: editorMessages } }[key]),
    },
  };
};

/**
 * Mounts the production upload-modal markup (from decidim-core's
 * `upload_templates` fixture) so the core Image extension's UploadDialog
 * can construct without throwing in jsdom.
 *
 * @returns {string} CSS selector pointing at the mounted dialog element.
 */
export const mountUploadDialogStub = () => {
  const host = document.createElement("div");
  host.innerHTML = uploadTemplates.redesign;
  document.body.append(host);
  return "#upload_dialog";
};

/**
 * Returns a freshly mounted empty `<div>` suitable as the TipTap `Editor`
 * mount target. Caller is responsible for `document.body.innerHTML = ""`
 * (or equivalent reset) between tests.
 */
export const createEditorContainer = () => {
  const element = document.createElement("div");
  document.body.append(element);
  return element;
};

/**
 * Calls `editor.destroy()` but swallows the null-reference errors that some
 * decidim-core extensions (e.g. Link's bubble menu) throw at teardown when
 * their `onCreate` did not fully initialise in jsdom. The test bodies still
 * see real failures; only the cleanup noise is suppressed.
 */
export const safeDestroy = (editor) => {
  try {
    editor.destroy();
  } catch (_e) {
    /* ignore jsdom-only destroy errors */
  }
};

/**
 * Polls the DOM until an element matching `selector` appears. Used to wait
 * for asynchronously mounted dialogs.
 */
export const waitFor = async (selector, timeoutMs = 500) => {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const el = document.querySelector(selector);
    if (el) return el;
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  throw new Error(`waitFor: ${selector} did not appear within ${timeoutMs}ms`);
};

/**
 * Polls the DOM until no element matches `selector`. Used to wait for
 * asynchronously closed dialogs.
 */
export const waitForRemoval = async (selector, timeoutMs = 500) => {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    if (!document.querySelector(selector)) return;
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  throw new Error(`waitForRemoval: ${selector} still present after ${timeoutMs}ms`);
};
