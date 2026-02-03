// This module ensures all imports of "leaflet" return the same global instance
// It must be used with webpack alias: leaflet$ -> this file

// First time: load real leaflet and set window.L
if (!window.L) {
  // Require the real leaflet module
  const leafletModule = require("leaflet/dist/leaflet-src.js");

  // If window.L wasn't set by the UMD wrapper, set it manually
  if (!window.L) {
    window.L = leafletModule;
  }
}

// IMPORTANT: Set module.exports BEFORE requiring plugins
// Plugins call require("leaflet") which returns this module's exports
// If we set exports after requiring plugins, they get an empty object
module.exports = window.L;

// Load plugins AFTER module.exports is set
// These plugins extend window.L (which is the same object as module.exports)
if (window.L && !window.L.MarkerClusterGroup) {
  require("leaflet.markercluster");
}
if (window.L && !window.L.FeatureGroup?.SubGroup) {
  require("leaflet.featuregroup.subgroup");
}
if (window.L && !window.L.TileLayer?.HERE) {
  require("leaflet-tilelayer-here");
}
