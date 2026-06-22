// JavaScript test runner configuration (jest).
//
// Purpose: integration-test cfj's editor extensions against the actual
// decidim-core (and friends) JavaScript that the production app loads. This
// is intentionally NOT a pure unit-test setup; the explicit goal is to
// detect breakage when decidim is upgraded.
//
// Companion files:
//   - spec/js/setup_polyfills.js   jsdom polyfills (Range / ClipboardEvent)
//   - spec/js/setup_matchers.js    custom matchers (toMatchHtml)
//   - spec/js/__mocks__/imageMock.js  stub for `import x from "images/..."`

const { execSync } = require("child_process");
const path = require("path");

// Resolves a Decidim gem's `app/packs` directory.
//
// Resolution order:
//   1. Environment variable override:
//        DECIDIM_<GEM_NAME_UPPER_SNAKE>_PATH=/abs/path/to/gem
//      Useful in CI where bundler may not be on PATH.
//   2. `bundle show <gem>` invoked at jest start.
//
// Throws (loudly) if neither succeeds. This is deliberate: silent fallback
// would let tests pass while production imports break, defeating the purpose
// of integration testing.
const findGemPath = (gemName) => {
  const envVarName = `DECIDIM_${gemName.replace(/-/g, "_").toUpperCase()}_PATH`;
  if (process.env[envVarName]) {
    return path.join(process.env[envVarName], "app", "packs");
  }
  try {
    const stdout = execSync(`bundle show ${gemName}`, { encoding: "utf-8" }).trim();
    return path.join(stdout, "app", "packs");
  } catch (e) {
    throw new Error(
      `[jest.config] Cannot resolve gem "${gemName}". ` +
      `Run \`bundle install\` first, or set ${envVarName} to override.\n` +
      `Bundler error: ${e.message}`
    );
  }
};

// Resolve everything against absolute paths so that imports inside the
// decidim-core gem (which lives outside this project tree) can still find
// cfj's `node_modules` and any sibling gem packs. `moduleDirectories` walks
// up from the requiring file and would miss cfj's node_modules when the
// requiring file is a gem path.
const cfjRoot = __dirname;
const modulePaths = [
  path.join(cfjRoot, "node_modules"),
  path.join(cfjRoot, "app", "packs"),
  findGemPath("decidim-core"),
];

module.exports = {
  testEnvironment: "jsdom",
  testEnvironmentOptions: { url: "https://decidim.dev/" },
  setupFiles: ["<rootDir>/spec/js/setup_polyfills.js", "raf/polyfill"],
  setupFilesAfterEnv: ["<rootDir>/spec/js/setup_matchers.js"],
  moduleFileExtensions: ["js"],
  moduleDirectories: ["node_modules"],
  modulePaths,
  moduleNameMapper: {
    "\\.(scss|css|less)$": "identity-obj-proxy",
    "^images/(.*)$": "<rootDir>/spec/js/__mocks__/imageMock.js",
    // Shared test helpers live under spec/js/. Import as `test/<name>` so the
    // path doesn't surface in production webpack bundles (which don't load
    // this alias).
    "^test/(.*)$": "<rootDir>/spec/js/$1",
  },
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
