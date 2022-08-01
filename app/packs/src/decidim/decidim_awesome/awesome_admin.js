// Webpack seems to "forgget" about certain libraries already being loaded 
// if javascript_pack_tag is called two times, let's include the whole Decidim admin here instead
import "entrypoints/decidim_admin"
// Custom scripts for awesome
import "src/decidim/decidim_awesome/admin/constraints"
import "src/decidim/decidim_awesome/admin/auto_edit"
import "src/decidim/decidim_awesome/admin/user_picker"
import "src/decidim/decidim_awesome/editors/tabs_focus"
import "src/decidim/decidim_awesome/admin/codemirror"
import "src/decidim/decidim_awesome/admin/check_redirections"
import {destroyQuillEditor, createQuillEditor, createMarkdownEditor} from "./editors/editor"

$(() => {
  $(".editor-container").each((_idx, container) => {
    destroyQuillEditor(container);
    if (window.DecidimAwesome.use_markdown_editor) {
      createMarkdownEditor(container);
    } else {
      createQuillEditor(container);
    }
  });
});
