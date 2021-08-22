// = require image-upload.min
// = require image-resize.min
// = require inscrybmde.min.js
// = require inline-attachment.js
// = require codemirror-4.inline-attachment.js
// = require jquery.inline-attachment.js
// = require europa.min.js
// = require_self

((exports) => {
  exports.DecidimAwesome = exports.DecidimAwesome || {};

  // Redefines Quill editor with images
  if(exports.DecidimAwesome.allow_images_in_full_editor  || exports.DecidimAwesome.allow_images_in_small_editor || exports.DecidimAwesome.use_markdown_editor) {

    const quillFormats = ["bold", "italic", "link", "underline", "header", "list", "video", "image", "alt"];

    const createQuillEditor = (container) => {
      const toolbar = $(container).data("toolbar");
      const disabled = $(container).data("disabled");

      let quillToolbar = [
        ["bold", "italic", "underline"],
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
        toolbar: quillToolbar
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
    };

    const createMarkdownEditor = (container) => {
      const t = window.DecidimAwesome.texts["drag_and_drop_image"];
      const token = $( 'meta[name="csrf-token"]' ).attr( 'content' );
      const $input = $(container).siblings('input[type="hidden"]');
      const $faker = $('<input type="hidden" name="faker-inscrybmde">');
      const $form = $(container).closest('form');
      const europa = new Europa();
      $faker.val(europa.convert($input.val()));
      $faker.insertBefore($(container));
      $(container).hide();
      const inscrybmde = new InscrybMDE({
        element: $faker[0],
        spellChecker: false,
        renderingConfig: {
          codeSyntaxHighlighting: true
        }
      });
      $faker[0].InscrybMDE = inscrybmde;

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

      // convert to html on submit
      $form.on("submit", () => {
        $input.val(inscrybmde.markdown(inscrybmde.value()));
      });
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
