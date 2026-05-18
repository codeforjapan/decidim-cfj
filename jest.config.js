// JavaScript test runner configuration (jest).
//
// Targets the cfj sources under `app/packs/src/decidim/cfj/` and third-party
// libraries under `node_modules`. Runs in a jsdom environment so TipTap and
// ProseMirror code can be exercised without a real browser.
//
// Companion files:
//   - spec/js/setup_polyfills.js   jsdom polyfills (Range / ClipboardEvent)
//   - spec/js/setup_matchers.js    custom matchers (toMatchHtml)
//   - spec/js/__mocks__/imageMock.js  stub for `import x from "images/..."`

module.exports = {
  testEnvironment: "jsdom",
  testEnvironmentOptions: { url: "https://decidim.dev/" },
  setupFiles: ["<rootDir>/spec/js/setup_polyfills.js", "raf/polyfill"],
  setupFilesAfterEnv: ["<rootDir>/spec/js/setup_matchers.js"],
  moduleFileExtensions: ["js"],
  moduleDirectories: ["node_modules", "app/packs"],
  moduleNameMapper: {
    "\\.(scss|css|less)$": "identity-obj-proxy",
    "^images/(.*)$": "<rootDir>/spec/js/__mocks__/imageMock.js",
  },
  // The babel preset is supplied inline here so the project root has no
  // .babelrc / babel.config.* file. This keeps the production webpack /
  // shakapacker build using its own preset chain (provided via @rails/webpacker
  // and friends) and avoids any accidental cross-pollination of test-only
  // transforms into the bundled assets.
  transform: {
    "\\.js$": ["babel-jest", {
      presets: [["@babel/preset-env", { targets: { node: "current" } }]],
    }],
  },
  testRegex: "\\.(test|spec)\\.js$",
  testPathIgnorePatterns: [
    "/node_modules/",
    "/vendor/",
    "/decidim-broadlistening/",
    "/old/",
    "/public/",
  ],
};
