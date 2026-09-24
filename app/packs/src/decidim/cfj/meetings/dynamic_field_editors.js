/**
 * Prepares a field `dynamic_fields.component` has just cloned so that the rich
 * text editors inside it work, doing the two things its clone path leaves
 * undone.
 *
 * 1. The upload dialog's id. It is a random "upload_<uuid>" baked into the
 *    `<script type="text/template">` block, and `.template()` only rewrites
 *    attributes containing the field's own placeholder (e.g.
 *    "meeting-agenda-item-id"), so every clone keeps the same dialog id and
 *    both `window.Decidim.currentDialogs` and the editor's own
 *    `document.querySelector(uploadDialogSelector)` can only resolve to one
 *    of them.
 * 2. Registering that dialog. The global initializer only scans for
 *    `[data-dialog]` on page load, so without this the editor's image button
 *    silently does nothing.
 *
 * Still needed on 0.32.1. Checked against upstream rather than assumed:
 *   - `upload_options[:modal_id] ||= "upload_#{SecureRandom.uuid}"` is
 *     byte for byte the same in v0.30.9, v0.31.7 and v0.32.1 (form_builder.rb),
 *     so the id is still random and still duplicated by cloning
 *   - `dynamic_fields.component` still rewrites only id/name/data-tabs-content/
 *     for/tabs_id/href/value, and only where the value contains the field's own
 *     placeholder. `data-dialog`, `data-dialog-close` and `data-options` are
 *     not touched
 *   - there is no Stimulus controller for dialogs, so cloned dialogs still have
 *     to be registered by hand
 * Removal: only once upstream makes modal_id derive from the field id, or ships
 * a dialog controller. Re-check the three points above before deleting.
 *
 * Editor construction is *not* our job on 0.31+: the editor container carries
 * `data-controller="editor"` and Stimulus builds it. Stimulus reacts to a
 * MutationObserver, whose callback is queued as a microtask, while
 * `_addField()` inserts the clone and calls `onAddField` synchronously — so
 * everything below still runs before the editor exists, which is exactly what
 * the rekey needs. (`window.createEditor` was dropped from
 * entrypoints/decidim_editor.js in 0.31; upstream's own agendas.js still calls
 * it and would raise here.)
 *
 * createDialog is passed in rather than imported so this stays free of
 * decidim-core imports, and so the ordering below can be tested directly.
 */

// Every attribute Decidim::UploadModalCell / decidim_modal derives from
// modal_id: the dialog root (`id`, `data-dialog`), its "-content" wrapper and
// `dialog-title-`/`dialog-desc-` headings (`id`), the close buttons
// (`data-dialog-close`), the file input and its label (`id`/`for`), and the
// editor's own `uploadDialogSelector` (inside the `data-options` JSON). A new
// one only needs adding here, rather than silently keeping the old id the way
// `dialog-title-` did, which cost the cloned dialog its `aria-labelledby`.
const ATTRIBUTES_CONTAINING_DIALOG_ID = ["id", "for", "data-dialog", "data-dialog-close", "data-options"];

const nextUploadDialogId = (() => {
  let uid = 0;

  return (baseId) => `${baseId}-${(uid += 1)}`;
})();

const parseEditorOptions = (container) => {
  try {
    return JSON.parse(container.dataset.options);
  } catch {
    return null;
  }
};

// Rewrites in place, by attribute assignment only. Replacing `innerHTML` on
// the `.editor` wrapper instead would detach the nodes of any sibling
// `.editor-container` still pending in the caller's static NodeList, so their
// own rekey would silently be skipped.
const replaceDialogId = (root, oldId, newId) => {
  [root, ...root.querySelectorAll("*")].forEach((element) => {
    ATTRIBUTES_CONTAINING_DIALOG_ID.forEach((attribute) => {
      const value = element.getAttribute(attribute);

      if (value && value.includes(oldId)) {
        element.setAttribute(attribute, value.split(oldId).join(newId));
      }
    });
  });
};

const rekeyUploadDialog = (container) => {
  const options = parseEditorOptions(container);
  const oldId = options && options.uploadDialogSelector && options.uploadDialogSelector.replace("#", "");
  if (!oldId) {
    return;
  }

  const wrapper = container.closest(".editor");
  if (!wrapper) {
    return;
  }

  replaceDialogId(wrapper, oldId, nextUploadDialogId(oldId));
};

export const prepareClonedEditors = (fieldElement, { createDialog }) => {
  // Rekeying has to happen before Stimulus connects the editor: the image
  // extension resolves uploadDialogSelector once, while the editor is built.
  fieldElement.querySelectorAll(".editor-container").forEach((container) => rekeyUploadDialog(container));

  // Registration only has to precede the first open: UploadDialog looks the
  // dialog up in window.Decidim.currentDialogs when the image button is
  // clicked, not while the editor is being constructed.
  fieldElement.querySelectorAll("[data-dialog]").forEach((dialog) => createDialog(dialog));
};
