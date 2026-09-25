/**
 * Unit spec for prepareClonedEditors.
 *
 * The fixture mirrors the markup FormBuilder#editor / #editor_upload
 * (Decidim::UploadModalCell + decidim_modal) render server-side: an
 * `.editor` wrapper holding an `.editor-container` whose `data-options`
 * references the dialog id, plus the dialog itself as a sibling, with every
 * place that id shows up - the `-content` wrapper, the `dialog-title-` /
 * `dialog-desc-` ids used for aria, the close buttons, and the file
 * input/label pair.
 */

import { prepareClonedEditors } from "src/decidim/cfj/meetings/dynamic_field_editors";

const buildEditor = (modalId) => `
  <div class="editor">
    <label for="meeting_agenda_description">Description</label>
    <div
      class="editor-container"
      data-options='{"uploadDialogSelector":"#${modalId}","contentTypes":{"image":["image/png"]}}'
    ></div>
    <div id="${modalId}" data-dialog="${modalId}">
      <div id="${modalId}-content">
        <h2 id="dialog-title-${modalId}" data-dialog-title></h2>
        <input type="file" id="files-${modalId}">
        <label for="files-${modalId}">choose file</label>
        <span id="dialog-desc-${modalId}"></span>
        <button type="button" data-dialog-close="${modalId}">cancel</button>
        <button type="button" data-dropzone-save data-dialog-close="${modalId}">save</button>
      </div>
    </div>
  </div>
`;

const dialogIdOf = (container) => JSON.parse(container.dataset.options).uploadDialogSelector.replace("#", "");

// The field element dynamic_fields.component hands to onAddField, with
// collaborators stubbed so each call can be inspected.
const activate = (html) => {
  document.body.innerHTML = `<div id="field">${html}</div>`;
  const createDialog = jest.fn();

  prepareClonedEditors(document.getElementById("field"), { createDialog });

  return { createDialog };
};

describe("prepareClonedEditors", () => {
  it("points the editor's uploadDialogSelector at a fresh id", () => {
    activate(buildEditor("upload_abc"));

    const newId = dialogIdOf(document.querySelector(".editor-container"));
    expect(newId).not.toBe("upload_abc");
    expect(document.getElementById(newId)).not.toBeNull();
    expect(document.getElementById(newId).dataset.dialog).toBe(newId);
  });

  it("rewrites every id-derived attribute of the dialog", () => {
    activate(buildEditor("upload_abc"));

    const newId = dialogIdOf(document.querySelector(".editor-container"));
    const dialog = document.getElementById(newId);

    expect(dialog.querySelector(`#${newId}-content`)).not.toBeNull();
    // These two back aria-labelledby/aria-describedby, which createDialog
    // resolves from the dialog's *current* id - leaving them behind cost the
    // cloned dialog its accessible name.
    expect(dialog.querySelector(`#dialog-title-${newId}`)).not.toBeNull();
    expect(dialog.querySelector(`#dialog-desc-${newId}`)).not.toBeNull();

    expect(dialog.querySelector(`#files-${newId}`)).not.toBeNull();
    expect(dialog.querySelector(`label[for="files-${newId}"]`)).not.toBeNull();
    expect(dialog.querySelectorAll(`[data-dialog-close="${newId}"]`).length).toBe(2);
  });

  it("leaves no reference to the original id behind", () => {
    activate(buildEditor("upload_abc"));

    expect(document.body.innerHTML).not.toContain("upload_abc\"");
    expect(document.body.innerHTML).not.toContain("upload_abc-content");
    expect(document.body.innerHTML).not.toContain("dialog-title-upload_abc<");
  });

  it("leaves unrelated attributes alone", () => {
    activate(buildEditor("upload_abc"));

    const container = document.querySelector(".editor-container");
    expect(document.querySelector("label[for='meeting_agenda_description']")).not.toBeNull();
    expect(JSON.parse(container.dataset.options).contentTypes).toEqual({ image: ["image/png"] });
  });

  // On 0.31+ Stimulus builds the editor, and its image extension resolves
  // uploadDialogSelector once while doing so. Stimulus reacts to a
  // MutationObserver, so it cannot run until the current synchronous work is
  // over - this pins that the rekey is finished by then.
  it("finishes rekeying before any MutationObserver callback can run", async () => {
    document.body.innerHTML = `<div id="field">${buildEditor("upload_abc")}</div>`;
    const field = document.getElementById("field");

    let optionsWhenObserverRan = null;
    new MutationObserver(() => {
      optionsWhenObserverRan = field.querySelector(".editor-container").dataset.options;
    }).observe(field, { attributes: true, childList: true, subtree: true });

    prepareClonedEditors(field, { createDialog: jest.fn() });

    await new Promise((resolve) => setTimeout(resolve, 0));

    expect(optionsWhenObserverRan).not.toBeNull();
    expect(optionsWhenObserverRan).not.toContain("#upload_abc\"");
    expect(optionsWhenObserverRan).toMatch(/"uploadDialogSelector":"#upload_abc-\d+"/);
  });

  it("registers every dialog in the field", () => {
    const { createDialog } = activate(buildEditor("upload_one") + buildEditor("upload_two"));

    expect(createDialog).toHaveBeenCalledTimes(2);
    createDialog.mock.calls.forEach(([dialog]) => {
      expect(dialog.dataset.dialog).toBe(dialog.id);
    });
  });

  it("does nothing to a container with no .editor ancestor", () => {
    expect(() =>
      activate(`<div class="editor-container" data-options='{"uploadDialogSelector":"#upload_orphan"}'></div>`)
    ).not.toThrow();

    expect(document.querySelector(".editor-container").dataset.options).toContain("#upload_orphan\"");
  });

  it("does nothing when data-options is missing or unparseable", () => {
    expect(() =>
      activate(`
        <div class="editor">
          <div class="editor-container"></div>
          <div class="editor-container" data-options="not json"></div>
        </div>
      `)
    ).not.toThrow();
  });

  describe("with two editor-container/dialog pairs sharing one .editor", () => {
    // Rewriting `wrapper.innerHTML` instead of assigning attributes would
    // detach the second pair's nodes while the first is being processed, so
    // its rekey would be skipped without any error. There is only ever one
    // `.editor-container` per `.editor` today, but nothing here relies on it.
    const twoPairsInOneEditor = `
      <div class="editor">
        <div class="editor-container" data-options='{"uploadDialogSelector":"#upload_first"}'></div>
        <div id="upload_first" data-dialog="upload_first">
          <input type="file" id="files-upload_first">
          <button type="button" data-dialog-close="upload_first">cancel</button>
        </div>

        <div class="editor-container" data-options='{"uploadDialogSelector":"#upload_second"}'></div>
        <div id="upload_second" data-dialog="upload_second">
          <input type="file" id="files-upload_second">
          <button type="button" data-dialog-close="upload_second">cancel</button>
        </div>
      </div>
    `;

    it("rekeys both to distinct, individually consistent ids", () => {
      activate(twoPairsInOneEditor);

      const newIds = Array.from(document.querySelectorAll(".editor-container")).map(dialogIdOf);
      expect(newIds[0]).toMatch(/^upload_first-\d+$/);
      expect(newIds[1]).toMatch(/^upload_second-\d+$/);

      newIds.forEach((id) => {
        const dialog = document.getElementById(id);
        expect(dialog).not.toBeNull();
        expect(dialog.dataset.dialog).toBe(id);
        expect(dialog.querySelector(`#files-${id}`)).not.toBeNull();
        expect(dialog.querySelector(`[data-dialog-close="${id}"]`)).not.toBeNull();
      });
    });
  });
});
