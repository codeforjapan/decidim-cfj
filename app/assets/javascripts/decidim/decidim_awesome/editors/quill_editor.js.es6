// = require image-upload.min
// = require image-resize.min
// = require inscrybmde.min.js
// = require inline-attachment.js
// = require codemirror-4.inline-attachment.js
// = require jquery.inline-attachment.js
// = require_self

((exports) => {
  exports.DecidimAwesome = exports.DecidimAwesome || {};

  /*** begin Decidim-cfj Extension ***/
    function __createCSS() {
        var css = document.createElement("style")
        css.type = "text/css"
        css.innerText = `
.ql-html-overlayContainer {
  background: #0000007d;
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 9999;
}

.ql-html-popupContainer {
  background: #ddd;
  position: absolute;
  top: 5%;
  left: 5%;
  right: 5%;
  bottom: 5%;
  border-radius: 10px;
}

.ql-html-textContainer {
  position: relative;
  width: calc(100% - 40px);
  height: calc(100% - 40px);
  padding: 20px;
}

.ql-html-textArea {
  background: #fff;
  position: absolute;
  left: 15px;
  width: calc(100% - 45px);
  height: calc(100% - 116px);
}

.ql-html-buttonCancel {
  margin-right: 20px;
}

.ql-html-popupTitle {
  margin: 0;
  display: block;
}

.ql-html-buttonGroup {
  position: absolute;
  bottom: 20px;
  transform: scale(1.5);
  left: calc(50% - 60px);
}
        `;
        document.head.appendChild(css);
    }
    __createCSS();

    function $create(elName) {
        return document.createElement(elName);
    }
    function $setAttr(el, key, value) {
        return el.setAttribute(key, value);
    }

    let debug = false;
    const Logger = {
        prefixString() {
            return `</> quill-html-edit-button: `;
        },
        get log() {
            if (!debug) {
                return (...any) => {};
            }
            const boundLogFn = console.log.bind(console, this.prefixString());
            return boundLogFn;
        }
    };

    class HtmlEditButton {
        constructor(quill, options) {
            debug = options && options.debug;
            Logger.log("logging enabled");
            // Add button to all quill toolbar instances
            const toolbarModule = quill.getModule("toolbar");
            if (!toolbarModule) {
                throw new Error(
                    'quill.HtmlEditButton requires the "toolbar" module to be included too'
                );
            }
            this.registerDivModule();
            let toolbarEl = toolbarModule.container;
            const buttonContainer = $create("span");
            $setAttr(buttonContainer, "class", "ql-formats");
            const button = $create("button");
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
        const popupContainer = $create("div");
        const overlayContainer = $create("div");
        const msg = options.msg || 'Edit HTML here, when you click "OK" the quill editor\'s contents will be replaced';
        const cancelText = options.cancelText || "Cancel";
        const okText = options.okText || "Ok";

        $setAttr(overlayContainer, "class", "ql-html-overlayContainer");
        $setAttr(popupContainer, "class", "ql-html-popupContainer");
        const popupTitle = $create("i");
        $setAttr(popupTitle, "class", "ql-html-popupTitle");
        popupTitle.innerText = msg;
        const textContainer = $create("div");
        textContainer.appendChild(popupTitle);
        $setAttr(textContainer, "class", "ql-html-textContainer");
        const codeBlock = $create("pre");
        $setAttr(codeBlock, "data-language", "xml");
        codeBlock.innerText = formatHTML(htmlFromEditor);
        const htmlEditor = $create("div");
        $setAttr(htmlEditor, "class", "ql-html-textArea");
        const buttonCancel = $create("button");
        buttonCancel.innerHTML = cancelText;
        $setAttr(buttonCancel, "class", "ql-html-buttonCancel");
        const buttonOk = $create("button");
        buttonOk.innerHTML = okText;
        const buttonGroup = $create("div");
        $setAttr(buttonGroup, "class", "ql-html-buttonGroup");

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
        Logger.log("formatHTML", {
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
  /*** end Decidim-cfj Extension ***/

  // Redefines Quill editor with images
  if(exports.DecidimAwesome.allow_images_in_full_editor  || exports.DecidimAwesome.allow_images_in_small_editor || exports.DecidimAwesome.use_markdown_editor) {

    const quillFormats = ["bold", "italic", "link", "underline", "header", "list", "video", "image", "alt", "break"];

    const createQuillEditor = (container) => {
      const toolbar = $(container).data("toolbar");
      const disabled = $(container).data("disabled");

      let quillToolbar = [
        ["bold", "italic", "underline", "linebreak"],
        [{ list: "ordered" }, { list: "bullet" }],
        ["link", "clean"]
      ];

      let addImage = false;

      if (toolbar === "full") {
        quillToolbar = [
          [{ header: [1, 2, 3, 4, 5, 6, false] }],
          ...quillToolbar
        ];
          if(exports.DecidimAwesome.allow_images_in_full_editor) {
            quillToolbar.push(["video", "image"]);
            addImage = true;
          } else {
            quillToolbar.push(["video"]);
          }
      } else if (toolbar === "basic") {
          if(exports.DecidimAwesome.allow_images_in_small_editor) {
            quillToolbar.push(["video", "image"]);
            addImage = true;
          } else {
            quillToolbar.push(["video"]);
          }
      } else if(exports.DecidimAwesome.allow_images_in_small_editor) {
        quillToolbar.push(["image"]);
        addImage = true;
      }

      let modules = {
        linebreak: {},
        toolbar: {
          container: quillToolbar,
          handlers: {
            "linebreak": exports.Decidim.Editor.lineBreakButtonHandler
          }
        },
        htmlEditButton: htmlEditButtonOptions
      };
      const $input = $(container).siblings('input[type="hidden"]');
      container.innerHTML = $input.val() || "";
      const token = $( 'meta[name="csrf-token"]' ).attr( 'content' );

      if(addImage) {
        modules.imageResize = {
          modules: ["Resize", "DisplaySize"]
        }
        modules.imageUpload = {
          url: exports.DecidimAwesome.editor_uploader_path, // server url. If the url is empty then the base64 returns
          method: 'POST', // change query method, default 'POST'
          name: 'image', // custom form name
          withCredentials: false, // withCredentials
          headers: { 'X-CSRF-Token': token }, // add custom headers, example { token: 'your-token'}
          // personalize successful callback and call next function to insert new url to the editor
          callbackOK: (serverResponse, next) => {
            $(quill.getModule("toolbar").container).last().removeClass('editor-loading')
            next(serverResponse.url);
          },
          // personalize failed callback
          callbackKO: serverError => {
            $(quill.getModule("toolbar").container).last().removeClass('editor-loading')
            alert(serverError.message);
          },
          checkBeforeSend: (file, next) => {
            $(quill.getModule("toolbar").container).last().addClass('editor-loading')
            next(file); // go back to component and send to the server
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

        if (text === "\n") {
          $input.val("");
        } else {
          $input.val(quill.root.innerHTML);
        }
      });

      if(addImage) {
        const t = window.DecidimAwesome.texts["drag_and_drop_image"];
        $(container).after(`<p class="help-text" style="margin-top:-1.5rem;">${t}</p>`);
      }

      // After editor is ready, linebreak_module deletes two extraneous new lines
      quill.emitter.emit("editor-ready");

      return quill;
    };

    const createMarkdownEditor = (container) => {
      $(container).hide();
      const t = window.DecidimAwesome.texts["drag_and_drop_image"];
      const token = $( 'meta[name="csrf-token"]' ).attr( 'content' );
      const $input = $(container).siblings('input[type="hidden"]');
      const inscrybmde = new InscrybMDE({
        element: $input[0],
        spellChecker: false,
        renderingConfig: {
          codeSyntaxHighlighting: true
        }
      });

      // Allow image upload
      if(window.DecidimAwesome.allow_images_in_markdown_editor) {
        $(inscrybmde.gui.statusbar).prepend(`<span class="help-text" style="float:left;margin:0;text-align:left;">${t}</span>`);
        inlineAttachment.editors.codemirror4.attach(inscrybmde.codemirror, {
          uploadUrl: window.DecidimAwesome.editor_uploader_path,
          uploadFieldName: "image",
          jsonFieldName: "url",
          extraHeaders: { "X-CSRF-Token": token }
        });
      }
    };

    const quillEditor = () => {
      $(".editor-container").each((idx, container) => {
        if(exports.DecidimAwesome.use_markdown_editor) {
          createMarkdownEditor(container);
        } else {
          createQuillEditor(container);
        }
      });
    };

    exports.Decidim = exports.Decidim || {};
    exports.Decidim.quillEditor = quillEditor;
    exports.Decidim.createQuillEditor = createQuillEditor;
    exports.Decidim.createMarkdownEditor = createMarkdownEditor;

  }
})(window);
