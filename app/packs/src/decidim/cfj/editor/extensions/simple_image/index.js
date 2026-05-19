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
      // Preserved so authors editing HTML directly do not lose layout intent
      // and basic styling hooks. All four pass Loofah's UserInputScrubber /
      // AdminInputScrubber allowlists, so they round-trip through display as
      // well — provided the surrounding context allows <img> at all
      // (admin scope; user scope still strips img regardless).
      width: {
        default: null,
      },
      height: {
        default: null,
      },
      class: {
        default: null,
      },
      id: {
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
})
