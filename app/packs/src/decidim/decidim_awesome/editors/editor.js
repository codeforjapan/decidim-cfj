/* eslint-disable require-jsdoc, func-style */

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
import "src/decidim/editor/clipboard_override"
import "src/decidim/vendor/image-resize.min"
import "src/decidim/vendor/image-upload.min"

const DecidimAwesome = window.DecidimAwesome || {};
const quillFormats = ["bold", "italic", "link", "underline", "header", "list", "video", "image", "alt", "break", "width", "style", "code", "blockquote", "indent"];

// A tricky way to destroy the quill editor
export function destroyQuillEditor(container) {
  if (container) {
    const content = $(container).find(".ql-editor").html();
    $(container).html(content);
    $(container).siblings(".ql-toolbar").remove();
    $(container).find("*[class*='ql-']").removeClass((index, className) => (className.match(/(^|\s)ql-\S+/g) || []).join(" "));
    $(container).removeClass((index, className) => (className.match(/(^|\s)ql-\S+/g) || []).join(" "));
    if ($(container).next().is("p.help-text")) {
      $(container).next().remove();
    }
  }
  else {
    console.error(`editor [${container}] not exists`);
  }
}

export function createQuillEditor(container) {
  // decidim-cfj custom start
  class HtmlEditButton {
    constructor(quill, options) {
      let debug = options && options.debug;
      console.log("logging enabled");
      // Add button to all quill toolbar instances
      const toolbarModule = quill.getModule("toolbar");
      if (!toolbarModule) {
        throw new Error(
            'quill.HtmlEditButton requires the "toolbar" module to be included too'
        );
      }
      this.registerDivModule();
      let toolbarEl = toolbarModule.container;
      const buttonContainer = document.createElement("span");
      buttonContainer.setAttribute("class", "ql-formats");
      const button = document.createElement("button");
      button.innerHTML = options.buttonHTML || "&lt;&gt;";
      button.title = options.buttonTitle || "Show HTML source";
      button.onclick = function(e) {
        e.preventDefault();
        launchPopupEditor(quill, options);
      };
      buttonContainer.appendChild(button);
      toolbarEl.appendChild(buttonContainer);
    }

    registerDivModule() {
      // To allow divs to be inserted into html editor
      // obtained from issue: https://github.com/quilljs/quill/issues/2040
      var Block = Quill.import("blots/block");
      class Div extends Block {}
      Div.tagName = "div";
      Div.blotName = "div";
      Div.allowedChildren = Block.allowedChildren;
      Div.allowedChildren.push(Block);
      Quill.register(Div);
    }
  }

  function launchPopupEditor(quill, options) {
    const htmlFromEditor = quill.container.querySelector(".ql-editor").innerHTML;
    const popupContainer = document.createElement("div");
    const overlayContainer = document.createElement("div");
    const msg = options.msg || 'Edit HTML here, when you click "OK" the quill editor\'s contents will be replaced';
    const cancelText = options.cancelText || "Cancel";
    const okText = options.okText || "Ok";

    overlayContainer.setAttribute("class", "ql-html-overlayContainer");
    popupContainer.setAttribute("class", "ql-html-popupContainer");
    const popupTitle = document.createElement("i");
    popupTitle.setAttribute("class", "ql-html-popupTitle");
    popupTitle.innerText = msg;
    const textContainer = document.createElement("div");
    textContainer.appendChild(popupTitle);
    textContainer.setAttribute("class", "ql-html-textContainer");
    const codeBlock = document.createElement("pre");
    codeBlock.setAttribute("data-language", "xml");
    codeBlock.innerText = formatHTML(htmlFromEditor);
    const htmlEditor = document.createElement("div");
    htmlEditor.setAttribute("class", "ql-html-textArea");
    const buttonCancel = document.createElement("button");
    buttonCancel.innerHTML = cancelText;
    buttonCancel.setAttribute("class", "ql-html-buttonCancel");
    const buttonOk = document.createElement("button");
    buttonOk.innerHTML = okText;
    const buttonGroup = document.createElement("div");
    buttonGroup.setAttribute("class", "ql-html-buttonGroup");

    buttonGroup.appendChild(buttonCancel);
    buttonGroup.appendChild(buttonOk);
    htmlEditor.appendChild(codeBlock);
    textContainer.appendChild(htmlEditor);
    textContainer.appendChild(buttonGroup);
    popupContainer.appendChild(textContainer);
    overlayContainer.appendChild(popupContainer);
    document.body.appendChild(overlayContainer);
    var editor = new Quill(htmlEditor, {
      modules: { syntax: options.syntax },
    });

    buttonCancel.onclick = function() {
      document.body.removeChild(overlayContainer);
    };
    overlayContainer.onclick = buttonCancel.onclick;
    popupContainer.onclick = function(e) {
      e.preventDefault();
      e.stopPropagation();
    };
    buttonOk.onclick = function() {
      const output = editor.container.querySelector(".ql-editor").innerText;
      const noNewlines = output
          .replace(/\s+/g, " ") // convert multiple spaces to a single space. This is how HTML treats them
          .replace(/(<[^\/<>]+>)\s+/g, "$1") // remove spaces after the start of a new tag
          .replace(/<\/(p|ol|ul)>\s/g, "</$1>") // remove spaces after the end of lists and paragraphs, they tend to break quill
          .replace(/\s<(p|ol|ul)>/g, "<$1>") // remove spaces before the start of lists and paragraphs, they tend to break quill
          .replace(/<\/li>\s<li>/g, "</li><li>") // remove spaces between list items, they tend to break quill
          .replace(/\s<\//g, "</") // remove spaces before the end of tags
          .replace(/(<[^\/<>]+>)\s(<[^\/<>]+>)/g, "$1$2") // remove space between multiple starting tags
          .trim();
      quill.container.querySelector(".ql-editor").innerHTML = noNewlines;
      document.body.removeChild(overlayContainer);
    };
  }

  // Adapted FROM jsfiddle here: https://jsfiddle.net/buksy/rxucg1gd/
  function formatHTML(code) {
    "use strict";
    let stripWhiteSpaces = true;
    let stripEmptyLines = true;
    const whitespace = " ".repeat(2); // Default indenting 4 whitespaces
    let currentIndent = 0;
    const newlineChar = "\n";
    let prevChar = null;
    let char = null;
    let nextChar = null;

    let result = "";
    for (let pos = 0; pos <= code.length; pos++) {
      prevChar = char;
      char = code.substr(pos, 1);
      nextChar = code.substr(pos + 1, 1);

      const isBrTag = code.substr(pos, 4) === "<br>";
      const isOpeningTag = char === "<" && nextChar !== "/" && !isBrTag;
      const isClosingTag = char === "<" && nextChar === "/" && !isBrTag;
      const isTagEnd = prevChar === ">" && char !== "<" && currentIndent > 0;
      const isTagNext = !isBrTag && !isOpeningTag && !isClosingTag && isTagEnd && code.substr(pos, code.substr(pos).indexOf("<")).trim() === "";
      if (isBrTag) {
        // If opening tag, add newline character and indention
        result += newlineChar;
        currentIndent--;
        pos += 4;
      }
      if (isOpeningTag) {
        // If opening tag, add newline character and indention
        result += newlineChar + whitespace.repeat(currentIndent);
        currentIndent++;
      }
      // if Closing tag, add newline and indention
      else if (isClosingTag) {
        // If there're more closing tags than opening
        if (--currentIndent < 0) currentIndent = 0;
        result += newlineChar + whitespace.repeat(currentIndent);
      }
      // remove multiple whitespaces
      else if (stripWhiteSpaces === true && char === " " && nextChar === " ")
        char = "";
      // remove empty lines
      else if (stripEmptyLines === true && char === newlineChar) {
        //debugger;
        if (code.substr(pos, code.substr(pos).indexOf("<")).trim() === "")
          char = "";
      }
      if(isTagEnd && !isTagNext) {
        result += newlineChar + whitespace.repeat(currentIndent);
      }

      result += char;
    }
    console.dir({
      before: code,
      after: result
    });
    return result;
  }
  const htmlEditButtonOptions = {
    debug: true, // logging, default:false
    msg: "HTMLソースを編集", //Custom message to display in the editor, default: Edit HTML here, when you click "OK" the quill editor's contents will be replaced
    okText: "OK", // Text to display in the OK button, default: Ok,
    cancelText: "キャンセル", // Text to display in the cancel button, default: Cancel
    buttonHTML: "&lt;&gt;", // Text to display in the toolbar button, default: <>
    buttonTitle: "HTMLソースを編集", // Text to display as the tooltip for the toolbar button, default: Show HTML source
    syntax: false // Show the HTML with syntax highlighting. Requires highlightjs on window.hljs (similar to Quill itself), default: false
  }
  // decidim-cfj custom end




  const toolbar = $(container).data("toolbar");
  const disabled = $(container).data("disabled");
  const allowedEmptyContentSelector = "iframe";

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
        } catch (evt) { console.error("Parsing error", evt); }
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
    if ((text === "\n" || text === "\n\n") && quill.root.querySelectorAll(allowedEmptyContentSelector).length === 0) {
      $input.val("");
    } else {
      const emptyParagraph = "<p><br></p>";
      const cleanHTML = quill.root.innerHTML.replace(
        new RegExp(`^${emptyParagraph}|${emptyParagraph}$`, "g"),
        ""
      );
      $input.val(cleanHTML);
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
  const text = DecidimAwesome.texts.drag_and_drop_image;
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
    $(inscrybmde.gui.statusbar).prepend(`<span class="help-text" style="float:left;margin:0;text-align:left;">${text}</span>`);
    window.inlineAttachment.editors.codemirror4.attach(inscrybmde.codemirror, {
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
