import AutoButtonsByPositionComponent from "src/decidim/admin/auto_buttons_by_position.component"
import AutoLabelByPositionComponent from "src/decidim/admin/auto_label_by_position.component"
import createSortList from "src/decidim/admin/sort_list.component"
import createDynamicFields from "src/decidim/admin/dynamic_fields.component"
import { createDialog } from "src/decidim/a11y"

const wrapperSelector = ".meeting-agenda-items";
const fieldSelector = ".meeting-agenda-item";
const childsWrapperSelector = ".meeting-agenda-item-childs";
const childFieldSelector = ".meeting-agenda-item-child";

const nextUploadDialogUid = (() => {
  let uid = 0;

  return () => {
    uid += 1;
    return uid;
  };
})();

// The description editor's upload dialog gets a random id (e.g.
// "upload_<uuid>") baked into the `<script type="text/template">` block
// that is cloned every time a new agenda item (or child) is added.
// `dynamic_fields.component`'s `.template()` only rewrites the `id`/`name`/
// `for`/... attributes that contain the field's own placeholder (e.g.
// "meeting-agenda-item-id"), so this unrelated id is copied verbatim on
// every clone. Adding a second item then duplicates it, which breaks the
// image upload dialog for one of the two. Every occurrence of the id
// (element ids, `data-dialog`, `data-options`, ...) is confined to this
// field's own `.editor` markup, so a plain text substitution there is
// enough to make each clone unique.
const parseEditorOptions = (container) => {
  try {
    return JSON.parse(container.dataset.options);
  } catch {
    return null;
  }
};

const rekeyUploadDialogs = ($field) => {
  $field[0].querySelectorAll(".editor-container").forEach((container) => {
    const options = parseEditorOptions(container);
    if (!options) {
      return;
    }

    const oldId = options.uploadDialogSelector && options.uploadDialogSelector.replace("#", "");
    if (!oldId) {
      return;
    }

    const wrapper = container.closest(".editor");
    wrapper.innerHTML = wrapper.innerHTML.split(oldId).join(`${oldId}-${nextUploadDialogUid()}`);
  });
};

const initializeDialogs = ($field) => {
  $field[0].querySelectorAll("[data-dialog]").forEach((el) => createDialog(el));
};

const autoLabelByPosition = new AutoLabelByPositionComponent({
  listSelector: ".meeting-agenda-item:not(.hidden)",
  labelSelector: ".card-title span:first",
  onPositionComputed: (el, idx) => {
    $(el).find("input[name$=\\[position\\]]").val(idx);
  }
});

const autoButtonsByPosition = new AutoButtonsByPositionComponent({
  listSelector: ".meeting-agenda-item:not(.hidden)",
  hideOnFirstSelector: ".move-up-agenda-item",
  hideOnLastSelector: ".move-down-agenda-item"
});

const createSortableList = () => {
  createSortList(".meeting-agenda-items-list:not(.published)", {
    handle: ".agenda-item-divider",
    placeholder: '<div style="border-style: dashed; border-color: #000"></div>',
    forcePlaceholderSize: true,
    onSortUpdate: () => { autoLabelByPosition.run() }
  });
};

const createSortableListChild = () => {
  createSortList(".meeting-agenda-item-childs-list:not(.published)", {
    handle: ".agenda-item-child-divider",
    placeholder: '<div style="border-style: dashed; border-color: #000"></div>',
    forcePlaceholderSize: true,
    onSortUpdate: () => { autoLabelByPosition.run() }
  });
};

const autoLabelByPositionChild = new AutoLabelByPositionComponent({
  listSelector: ".meeting-agenda-item-child:not(.hidden)",
  labelSelector: ".card-title span:first",
  onPositionComputed: (el, idx) => {
    $(el).find("input[name$=\\[position\\]]").val(idx);
  }
});

const autoButtonsByPositionChild = new AutoButtonsByPositionComponent({
  listSelector: ".meeting-agenda-item-child:not(.hidden)",
  hideOnFirstSelector: ".move-up-agenda-item-child",
  hideOnLastSelector: ".move-down-agenda-item-child"
});

const createDynamicFieldsForAgendaItemChilds = (fieldId) => {
  return createDynamicFields({
    placeholderId: "meeting-agenda-item-child-id",
    wrapperSelector: `#${fieldId} ${childsWrapperSelector}`,
    containerSelector: ".meeting-agenda-item-childs-list",
    fieldSelector: childFieldSelector,
    addFieldButtonSelector: ".add-agenda-item-child",
    removeFieldButtonSelector: ".remove-agenda-item-child",
    moveUpFieldButtonSelector: ".move-up-agenda-item-child",
    moveDownFieldButtonSelector: ".move-down-agenda-item-child",

    onAddField: ($field) => {
      createSortableListChild();

      rekeyUploadDialogs($field);
      $field[0].querySelectorAll(".editor-container").forEach((el) => {
        window.createEditor(el);
      });
      initializeDialogs($field);

      autoLabelByPositionChild.run();
      autoButtonsByPositionChild.run();
    },
    onRemoveField: () => {
      autoLabelByPositionChild.run();
      autoButtonsByPositionChild.run();
    },
    onMoveUpField: () => {
      autoLabelByPositionChild.run();
      autoButtonsByPositionChild.run();
    },
    onMoveDownField: () => {
      autoLabelByPositionChild.run();
      autoButtonsByPositionChild.run();
    }
  });
};

const dynamicFieldsForAgendaItemChilds = {};

const setupInitialAgendaItemChildAttributes = ($target) => {
  const fieldId = $target.attr("id");

  dynamicFieldsForAgendaItemChilds[fieldId] = createDynamicFieldsForAgendaItemChilds(fieldId);

}

const hideDeletedAgendaItem = ($target) => {
  const inputDeleted = $target.find("input[name$=\\[deleted\\]]").val();

  if (inputDeleted === "true") {
    $target.addClass("hidden");
    $target.hide();
  }
};

createDynamicFields({
  placeholderId: "meeting-agenda-item-id",
  wrapperSelector: wrapperSelector,
  containerSelector: ".meeting-agenda-items-list",
  fieldSelector: fieldSelector,
  addFieldButtonSelector: ".add-agenda-item",
  removeFieldButtonSelector: ".remove-agenda-item",
  moveUpFieldButtonSelector: ".move-up-agenda-item",
  moveDownFieldButtonSelector: ".move-down-agenda-item",
  onAddField: ($field) => {
    // createDynamicFieldsForAgendaItemChilds($field);
    setupInitialAgendaItemChildAttributes($field);
    createSortableList();

    rekeyUploadDialogs($field);
    $field.find(".editor-container").each((idx, el) => {
      window.createEditor(el);
    });
    initializeDialogs($field);

    autoLabelByPosition.run();
    autoButtonsByPosition.run();
  },
  onRemoveField: () => {
    autoLabelByPosition.run();
    autoButtonsByPosition.run();
  },
  onMoveUpField: () => {
    autoLabelByPosition.run();
    autoButtonsByPosition.run();
  },
  onMoveDownField: () => {
    autoLabelByPosition.run();
    autoButtonsByPosition.run();
  }
});

createSortableList();

$(fieldSelector).each((idx, el) => {
  const $target = $(el);

  hideDeletedAgendaItem($target);
  setupInitialAgendaItemChildAttributes($target);
});

autoLabelByPosition.run();
autoButtonsByPosition.run();
autoLabelByPositionChild.run();
autoButtonsByPositionChild.run();
