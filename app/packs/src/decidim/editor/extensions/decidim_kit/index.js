import { Extension } from "@tiptap/core";

import StarterKit from "@tiptap/starter-kit";
import CodeBlock from "@tiptap/extension-code-block";
import Underline from "@tiptap/extension-underline";

import CharacterCount from "src/decidim/editor/extensions/character_count";
import Bold from "src/decidim/editor/extensions/bold";
import Dialog from "src/decidim/editor/extensions/dialog";
import Hashtag from "src/decidim/editor/extensions/hashtag";
import Heading from "src/decidim/editor/extensions/heading";
import OrderedList from "src/decidim/editor/extensions/ordered_list";
import Image from "src/decidim/editor/extensions/image";
import Indent from "src/decidim/editor/extensions/indent";
import Link from "src/decidim/editor/extensions/link";
import Mention from "src/decidim/editor/extensions/mention";
import VideoEmbed from "src/decidim/editor/extensions/video_embed";
import Emoji from "src/decidim/editor/extensions/emoji";
import TagEdit from "src/decidim/cfj/editor/extensions/tag_edit";
import Iframe from "src/decidim/cfj/editor/extensions/iframe";
import { SimpleImage } from "src/decidim/cfj/editor/extensions/simple_image";

export default Extension.create({
  name: "decidimKit",

  addOptions() {
    return {
      characterCount: { limit: null },
      heading: { levels: [2, 3, 4, 5, 6] },
      link: { allowTargetControl: false },
      videoEmbed: false,
      image: {
        uploadDialogSelector: null,
        uploadImagesPath: null,
        contentTypes: /^image\/(jpe?g|png|svg|webp)$/i
      },
      hashtag: false,
      mention: false,
      iframe: true,
      emoji: false
    };
  },

  addExtensions() {
    const extensions = [
      StarterKit.configure({
        heading: false,
        bold: false,
        orderedList: false,
        codeBlock: false
      }),
      CharacterCount.configure(this.options.characterCount),
      Link.configure({ openOnClick: false, ...this.options.link }),
      Bold,
      Dialog,
      Indent,
      OrderedList,
      CodeBlock,
      TagEdit,
      Underline
    ];

    if (this.options.heading !== false) {
      extensions.push(Heading.configure(this.options.heading));
    }

    if (this.options.videoEmbed !== false) {
      extensions.push(VideoEmbed.configure(this.options.videoEmbed));
    }

    if (this.options.image !== false && this.options.image.uploadDialogSelector) {
      extensions.push(Image.configure(this.options.image));
    }

    if (this.options.hashtag !== false) {
      extensions.push(Hashtag.configure(this.options.hashtag));
    }

    if (this.options.mention !== false) {
      extensions.push(Mention.configure(this.options.mention));
    }

    if (this.options.emoji !== false) {
      extensions.push(Emoji.configure(this.options.emoji));
    }

    if (this.options.iframe !== false) {
      extensions.push(Iframe.configure(this.options.iframe));
    }

    extensions.push(SimpleImage.configure(true));

    return extensions;
  }
});
