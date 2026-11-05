/**
 * Activates the rich text editors of a field `dynamic_fields.component` has
 * just cloned, doing the two things its clone path leaves undone.
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
 * Fixed upstream in 0.31 (decidim/decidim#14184 made modal_id derive from
 * the field id, so the generic placeholder substitution covers it).
 * Removal: delete this file and its use in
 * src/decidim/meetings/admin/agendas once Decidim is 0.31 or newer.
 *
 * Collaborators are passed in rather than imported so this stays free of
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

export const activateEditors = (fieldElement, { createEditor, createDialog }) => {
  const containers = fieldElement.querySelectorAll(".editor-container");

  // Rekeying has to come first: the editor's image extension resolves
  // uploadDialogSelector once, while the editor is being constructed.
  containers.forEach((container) => rekeyUploadDialog(container));
  containers.forEach((container) => createEditor(container));

  fieldElement.querySelectorAll("[data-dialog]").forEach((dialog) => createDialog(dialog));
};
