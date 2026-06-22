// jest mock for `import iconUrl from "images/...svg"` style imports that go
// through webpack at build time but are not handled by jest's module resolver.
module.exports = "test-image-stub.svg";
