import { Node } from "@tiptap/core"

const isAllowedDomain = (src) => {
  if (!src) return false;
  const domainPattern = new RegExp(`^https://.*/`);
  if (domainPattern.test(src)) {
    return true;
  }
  return false;
};

export default Node.create({
  name: "iframe",
  group: "block",
  atom: true,
  addOptions() {
    return {
      allowFullscreen: true,
      HTMLAttributes: {
        class: "iframe-wrapper"
      }
    }
  },
  addAttributes() {
    return {
      src: {
        default: null,
        parseHTML: (element) => element.getAttribute("src"),
        renderHTML: (attributes) => {
          if (!isAllowedDomain(attributes.src)) {
            return {};
          }
          return { src: attributes.src };
        },
      },
      title: {
        default: null,
      },
      frameborder: {
        default: 0,
      },
      width: {
        default: null,
      },
      height: {
        default: null,
      },
      style: {
        default: null,
      },
      scrolling: {
        default: null,
      },
      allowfullscreen: {
        default: this.options.allowFullscreen,
        parseHTML: () => this.options.allowFullscreen,
      },
    }
  },
  parseHTML() {
    return [{
      tag: "iframe",
    }]
  },
  renderHTML({ HTMLAttributes }) {
    return ["div", this.options.HTMLAttributes, ["iframe", HTMLAttributes]]
  },
  addCommands() {
    return {
      setIframe: (options) => ({ tr, dispatch }) => {
        const { selection } = tr
        const node = this.type.create(options)

        if (dispatch) {
          tr.replaceRangeWith(selection.from, selection.to, node)
        }

        return true
      },
    }
  },
})
