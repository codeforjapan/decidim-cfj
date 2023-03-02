export class HtmlEditButton {
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
      this.launchPopupEditor(quill, options);
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

  launchPopupEditor(quill, options) {
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
    codeBlock.innerText = this.formatHTML(htmlFromEditor);
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
  formatHTML(code) {
    // "use strict";
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
}

export const htmlEditButtonOptions = {
  debug: true, // logging, default:false
  msg: "HTMLソースを編集", //Custom message to display in the editor, default: Edit HTML here, when you click "OK" the quill editor's contents will be replaced
  okText: "OK", // Text to display in the OK button, default: Ok,
  cancelText: "キャンセル", // Text to display in the cancel button, default: Cancel
  buttonHTML: "&lt;&gt;", // Text to display in the toolbar button, default: <>
  buttonTitle: "HTMLソースを編集", // Text to display as the tooltip for the toolbar button, default: Show HTML source
  syntax: false // Show the HTML with syntax highlighting. Requires highlightjs on window.hljs (similar to Quill itself), default: false
}
