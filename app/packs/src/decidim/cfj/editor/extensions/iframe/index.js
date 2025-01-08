import { Node } from "@tiptap/core"

const iframeAllowedDomains = ["www.youtube.com", "vimeo.com", "docs.google.com"];

const isAllowedDomain = (src) => {
  if (!src) return false;
  for (const domain of iframeAllowedDomains) {
    const domainPattern = new RegExp(`^https://${domain}/`);
    if (domainPattern.test(src)) {
      return true;
    }
  }
  return false;
};

export default Node.create({
  name: "iframe",
  group: "block",
  atom: true,
  defaultOptions: {
    allowFullscreen: true,
    HTMLAttributes: {
      class: "iframe-wrapper"
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
