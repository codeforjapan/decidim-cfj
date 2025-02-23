import {
  mergeAttributes,
  Node,
} from '@tiptap/core'

/**
 * This extension allows you to insert images, usually inline.
 * @see https://www.tiptap.dev/api/nodes/image
 */
export const SimpleImage = Node.create({
  name: 'simpleImage',

  addOptions() {
    return {
      inline: true,
      HTMLAttributes: {},
    }
  },

  inline() {
    return this.options.inline
  },

  group() {
    return this.options.inline ? 'inline' : 'block'
  },

  draggable: true,

  addAttributes() {
    return {
      src: {
        default: null,
      },
      alt: {
        default: null,
      },
      title: {
        default: null,
      },
    }
  },

  parseHTML() {
    return [{ tag: 'img[src]:not([src^="data:"])' }]
  },

  renderHTML({ HTMLAttributes }) {
    return ['img', mergeAttributes(this.options.HTMLAttributes, HTMLAttributes)]
  },

  addCommands() {
    return {
      setImage: options => ({ commands }) => {
        return commands.insertContent({
          type: this.name,
          attrs: options,
        })
      },
    }
  },
})
