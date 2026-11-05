// Smoke test that the jest setup itself is wired correctly.
// Verifies:
//   - jest can execute a `.test.js` file under spec/js/
//   - babel-jest transforms ES module `import` syntax
//   - the custom toMatchHtml matcher (defined in setup_matchers.js) is loaded
//   - jsdom test environment is available (Range / Document globals exist)
//   - modules from node_modules can be imported (sanity of moduleDirectories)

import { Node } from "@tiptap/core";

describe("jest runner sanity", () => {
  it("can run a trivial assertion", () => {
    expect(2 + 2).toBe(4);
  });

  it("transforms ES module imports via babel-jest", () => {
    expect(typeof Node.create).toBe("function");
  });

  it("has the jsdom environment available", () => {
    expect(typeof document).toBe("object");
    expect(typeof Range).toBe("function");
  });

  it("loads the custom toMatchHtml matcher", () => {
    expect("<p>hello</p>").toMatchHtml(`
      <p>hello</p>
    `);
  });
});
