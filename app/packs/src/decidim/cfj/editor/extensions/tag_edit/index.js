import { Node } from "@tiptap/core";
import { Plugin } from "prosemirror-state";
import InputDialog from "src/decidim/editor/common/input_dialog";
import TextDialog from "./text_dialog";

/**
 * New HTML Tag Editor for TipTap
 */
export default Node.create({
  name: "tagEdit",

  addCommands() {
    return {
      tagEditDialog: () => async ({ dispatch }) => {
        if (dispatch) {
          const tagEditDialog = new TextDialog(this.editor, {
            name: 'tagsrc',
            label: 'HTMLソース',
            rows: 10,
            cols: 80,
           });
          const tagsrc = this.editor.getHTML();

          const dialogState = await tagEditDialog.toggle({ tagsrc });
          if (dialogState !== "save") {
            return false;
          }

          const newTagsrc = tagEditDialog.getValue("tagsrc");
          this.editor.commands.setContent(newTagsrc, true);
          this.editor.commands.focus(null, { scrollIntoView: false });
          return false;
        }
        return true;
      }
    }
  },

  addProseMirrorPlugins() {
    const editor = this.editor;

    return [
      new Plugin({
        props: {
          handleDoubleClick() {
            if (!editor.isActive("tagEdit")) {
              return false;
            }

            editor.chain().focus().tagEditDialog().run();
            return true;
          }
        }
      })
    ];
  }
});

