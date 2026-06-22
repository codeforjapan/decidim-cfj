// jest setup file - runs BEFORE the jest framework (so `expect` is not yet
// available here; for matchers see setup_matchers.js).
//
// Provides jsdom polyfills for DOM APIs that TipTap / ProseMirror rely on but
// jsdom does not implement.

// Layout-related APIs on Range. ProseMirror queries selection rects and would
// otherwise throw `getBoundingClientRect is not a function` in jsdom.
if (typeof Range !== "undefined") {
  Object.assign(Range.prototype, {
    getBoundingClientRect: () => ({ bottom: 0, height: 0, left: 0, right: 0, top: 0, width: 0 }),
    getClientRects: () => ({ item: () => null, length: 0, [Symbol.iterator]: function* () {} }),
  });
}

// jsdom does not define ClipboardEvent / DragEvent; TipTap's paste / drop
// plugins reference these constructors at extension registration time, so
// stub them with simple Event subclasses.
if (typeof window !== "undefined") {
  if (typeof window.ClipboardEvent === "undefined") {
    window.ClipboardEvent = class ClipboardEvent extends Event {};
  }
  if (typeof window.DragEvent === "undefined") {
    window.DragEvent = class DragEvent extends Event {};
  }
}
