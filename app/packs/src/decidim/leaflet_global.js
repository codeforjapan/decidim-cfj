// This module ensures all imports of "leaflet" return the same global instance.
// Used with webpack alias: leaflet$ -> this file
//
// When any module does `import L from "leaflet"` or `require("leaflet")`,
// webpack resolves it to this file, ensuring all bundles share the same
// Leaflet instance via window.L.
//
// Plugins (markercluster, etc.) are loaded by each module that needs them.
// They call require("leaflet") which returns window.L, and extend it.

if (!window.L) {
  window.L = require("leaflet/dist/leaflet-src.js");
}

module.exports = window.L;
