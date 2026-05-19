// jest setup file - runs AFTER the jest framework is installed, so `expect`
// is available. Use this file to register custom matchers.

expect.extend({
  toMatchHtml(received, expected) {
    // Strip newlines + indentation introduced by template literals so tests
    // can be written with readable multi-line HTML.
    const uglyHTML = expected.replace(/[\r\n]+\s+/g, "");
    const pass = received === uglyHTML;
    return {
      pass,
      message: () =>
        `Expected HTML to ${pass ? "not " : ""}match.\n` +
        `Expected: ${uglyHTML}\n` +
        `Received: ${received}`,
    };
  },
});
