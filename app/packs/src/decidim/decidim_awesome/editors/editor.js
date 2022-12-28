/* eslint-disable require-jsdoc */

/*
* Since version 0.25 we follow a different strategy and opt to destroy and override completely the original editor
* That's because editors are instantiated directly instead of creating a global function to instantiate them
*/

import lineBreakButtonHandler from "src/decidim/editor/linebreak_module"
import InscrybMDE from "inscrybmde"
import Europa from "europa"
import "inline-attachment/src/inline-attachment";
import "inline-attachment/src/codemirror-4.inline-attachment";
import "inline-attachment/src/jquery.inline-attachment";
import hljs from "highlight.js";
import "highlight.js/styles/github.css";

// In 0.26 these files come with Decidim in the folder src/decidim/vendor so the awesome one's could be removed
import "src/vendor/image-resize.min"
import "src/vendor/image-upload.min"

import { HtmlEditButton, htmlEditButtonOptions } from "src/decidim/cfj/html_edit_button";

const DecidimAwesome = window.DecidimAwesome || {};
const quillFormats = ["bold", "italic", "link", "underline", "header", "list", "video", "image", "alt", "break", "width", "style", "code", "blockquote", "indent"];

// A tricky way to destroy the quill editor
export function destroyQuillEditor(container) {
  if (container) {
    const content = $(container).find(".ql-editor").html();
    $(container).html(content);
    $(container).siblings(".ql-toolbar").remove();
    $(container).find("*[class*='ql-']").removeClass((index, class_name) => (class_name.match(/(^|\s)ql-\S+/g) || []).join(" "));
    $(container).removeClass((index, class_name) => (class_name.match(/(^|\s)ql-\S+/g) || []).join(" "));
    if ($(container).next().is("p.help-text")) {
      $(container).next().remove();
    }
  }
  else {
    console.error(`editor [${container}] not exists`);
  }
}

export function createQuillEditor(container) {
  const toolbar = $(container).data("toolbar");
  const disabled = $(container).data("disabled");

  let quillToolbar = [
    ["bold", "italic", "underline", "linebreak"],
    [{ list: "ordered" }, { list: "bullet" }],
    ["link", "clean"],
    ["code", "blockquote"],
    [{ "indent": "-1"}, { "indent": "+1" }]
  ];

  let addImage = false;

  if (toolbar === "full") {
    quillToolbar = [
      [{ header: [1, 2, 3, 4, 5, 6, false] }],
      ...quillToolbar
    ];
    if (DecidimAwesome.allow_images_in_full_editor) {
      quillToolbar.push(["video", "image"]);
      addImage = true;
    } else {
      quillToolbar.push(["video"]);
    }
  } else if (toolbar === "basic") {
    if (DecidimAwesome.allow_images_in_small_editor) {
      quillToolbar.push(["video", "image"]);
      addImage = true;
    } else {
      quillToolbar.push(["video"]);
    }
  } else if (DecidimAwesome.allow_images_in_small_editor) {
    quillToolbar.push(["image"]);
    addImage = true;
  }

  let modules = {
    linebreak: {},
    toolbar: {
      container: quillToolbar,
      handlers: {
        "linebreak": lineBreakButtonHandler
      }
    },
    htmlEditButton: htmlEditButtonOptions
  };

  const $input = $(container).siblings('input[type="hidden"]');
  container.innerHTML = $input.val() || "";
  const token = $('meta[name="csrf-token"]').attr("content");
  if (addImage) {
    modules.imageResize = {
      modules: ["Resize", "DisplaySize"]
    }
    modules.imageUpload = {
      url: DecidimAwesome.editor_uploader_path,
      method: "POST",
      name: "image",
      withCredentials: false,
      headers: { "X-CSRF-Token": token },
      callbackOK: (serverResponse, next) => {
        $("div.ql-toolbar").last().removeClass("editor-loading")
        next(serverResponse.url);
      },
      callbackKO: (serverError) => {
        $("div.ql-toolbar").last().removeClass("editor-loading")
        let msg = serverError && serverError.body;
        try {
          msg = JSON.parse(msg).message;
        } catch (e) { console.error("Parsing error", e); }
        console.error(`Image upload error: ${msg}`);
        let $p = $(`<p class="text-alert help-text">${msg}</p>`);
        $(container).after($p)
        setTimeout(() => {
          $p.fadeOut(1000, () => {
            $p.destroy();
          });
        }, 3000);
      },
      checkBeforeSend: (file, next) => {
        $("div.ql-toolbar").last().addClass("editor-loading")
        next(file);
      }
    }
  }
  Quill.register("modules/htmlEditButton", HtmlEditButton);
  const quill = new Quill(container, {
    modules: modules,
    formats: quillFormats,
    theme: "snow"
  });

  if (disabled) {
    quill.disable();
  }

  quill.on("text-change", () => {
    const text = quill.getText();

    // Triggers CustomEvent with the cursor position
    // It is required in input_mentions.js
    let event = new CustomEvent("quill-position", {
      detail: quill.getSelection()
    });
    container.dispatchEvent(event);

    if (text === "\n" || text === "\n\n") {
      $input.val("");
    } else {
      $input.val(quill.root.innerHTML);
    }
  });
  // After editor is ready, linebreak_module deletes two extraneous new lines
  quill.emitter.emit("editor-ready");

  if (addImage) {
    const text = $(container).data("dragAndDropHelpText") || DecidimAwesome.texts.drag_and_drop_image;
    $(container).after(`<p class="help-text" style="margin-top:-1.5rem;">${text}</p>`);
  }

  // After editor is ready, linebreak_module deletes two extraneous new lines
  quill.emitter.emit("editor-ready");

  return quill;
}

export function createMarkdownEditor(container) {
  const t = DecidimAwesome.texts.drag_and_drop_image;
  const token = $('meta[name="csrf-token"]').attr("content");
  const $input = $(container).siblings('input[type="hidden"]');
  const $faker = $('<textarea name="faker-inscrybmde"/>');
  const $form = $(container).closest("form");
  const europa = new Europa();
  $faker.val(europa.convert($input.val()));
  $faker.insertBefore($(container));
  $(container).hide();
  const inscrybmde = new InscrybMDE({
    element: $faker[0],
    spellChecker: false,
    renderingConfig: {
      codeSyntaxHighlighting: true,
      hljs: hljs
    }
  });
  $faker[0].InscrybMDE = inscrybmde;

  // Allow image upload
  if (DecidimAwesome.allow_images_in_markdown_editor) {
    $(inscrybmde.gui.statusbar).prepend(`<span class="help-text" style="float:left;margin:0;text-align:left;">${t}</span>`);
    inlineAttachment.editors.codemirror4.attach(inscrybmde.codemirror, {
      uploadUrl: DecidimAwesome.editor_uploader_path,
      uploadFieldName: "image",
      jsonFieldName: "url",
      extraHeaders: { "X-CSRF-Token": token }
    });
  }

  // convert to html on submit
  $form.on("submit", () => {
    // e.preventDefault();
    $input.val(inscrybmde.markdown(inscrybmde.value()));
  });
}
