import { Editor, Extension } from "@tiptap/core";
import StarterKit from "@tiptap/starter-kit";

/**
 * HTML edit extension for the Tiptap editor.
 */
export default Extension.create({
  name: 'htmlEdit',

  onCreate() {
    const htmlEditButtonOptions = {
      title: "HTMLソースを編集",
      okText: "OK",
      cancelText: "キャンセル",
    };

    const createEditorContainer = (options) => {
      const overlayContainer = document.createElement("div");
      overlayContainer.setAttribute("class", "html-edit-overlay");
      const popupContainer = document.createElement("div");
      popupContainer.setAttribute("class", "html-edit-popup-container");
      const popupTitle = document.createElement("div");
      popupTitle.setAttribute("class", "html-edit-popup-title");
      popupTitle.innerText = options.title;
      const htmlEditor = document.createElement("div");
      htmlEditor.setAttribute("class", "html-edit-box");
      const htmlEditTextarea = document.createElement("textarea");
      htmlEditTextarea.setAttribute("class", "html-edit-textarea");
      const buttonGroup = document.createElement("div");
      buttonGroup.setAttribute("class", "html-edit-button-group");
      const buttonCancel = document.createElement("button");
      buttonCancel.setAttribute("class", "html-edit-button-cancel");
      buttonCancel.innerHTML = options.cancelText;
      const buttonOk = document.createElement("button");
      buttonOk.setAttribute("class", "html-edit-button-save");
      buttonOk.innerHTML = options.okText;

      buttonGroup.appendChild(buttonCancel);
      buttonGroup.appendChild(buttonOk);
      htmlEditor.appendChild(popupTitle);
      htmlEditor.appendChild(htmlEditTextarea);
      htmlEditor.appendChild(buttonGroup);
      popupContainer.appendChild(htmlEditor);
      overlayContainer.appendChild(popupContainer);
      document.body.appendChild(overlayContainer);

      buttonOk.addEventListener('click', () => {
        const updatedHtml = htmlEditTextarea.value;
        this.editor.commands.setContent(updatedHtml, { html: true });
        overlayContainer.style.display = 'none';
      });

      buttonCancel.addEventListener('click', () => {
        overlayContainer.style.display = 'none';
      });
    };

    /* add Editor if html-editor-overlay is not found */
    if (document.querySelectorAll('.html-edit-overlay').length === 0) {
      createEditorContainer(htmlEditButtonOptions);
    }
  },

  addCommands() {
    return {
      openHtmlEditModal: () => ({ editor }) => {

        // Adapted FROM jsfiddle here: https://jsfiddle.net/buksy/rxucg1gd/
        const formatHtml = (code) => {
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
            else if (char === " " && nextChar === " ")
              char = "";
            // remove empty lines
            else if (char === newlineChar) {
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

        const noNewlines = (src) => {
          const replaced = src
                .replace(/\s+/g, " ") // convert multiple spaces to a single space. This is how HTML treats them
                .replace(/(<[^\/<>]+>)\s+/g, "$1") // remove spaces after the start of a new tag
                .replace(/<\/(p|ol|ul)>\s/g, "</$1>") // remove spaces after the end of lists and paragraphs, they tend to break quill
                .replace(/\s<(p|ol|ul)>/g, "<$1>") // remove spaces before the start of lists and paragraphs, they tend to break quill
                .replace(/<\/li>\s<li>/g, "</li><li>") // remove spaces between list items, they tend to break quill
                .replace(/\s<\//g, "</") // remove spaces before the end of tags
                .replace(/(<[^\/<>]+>)\s(<[^\/<>]+>)/g, "$1$2") // remove space between multiple starting tags
                .trim();
          return replaced;
        };

        const html = editor.getHTML();
        document.querySelector('.html-edit-textarea').value = formatHtml(html);
        document.querySelector('.html-edit-overlay').style.display = 'flex';
      }
    };
  }
});
