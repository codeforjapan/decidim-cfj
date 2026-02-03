/* eslint no-console:0 */
// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/packs and only use these pack files to reference
// that code so it'll be compiled.
//
// To reference this file, add <%= javascript_pack_tag 'application' %> to the appropriate
// layout file, like app/views/layouts/application.html.erb

// Uncomment to copy all static images under ../images to the output folder and reference
// them with the image_pack_tag helper in views (e.g <%= image_pack_tag 'rails.png' %>)
// or the `imagePath` JavaScript helper below.
//
// const images = require.context('../images', true)
// const imagePath = (name) => images(name, true)

// Activate Active Storage
// import * as ActiveStorage from "@rails/activestorage"
// ActiveStorage.start()

// import "src/decidim/decidim_awesome/awesome_admin"

// Leaflet initialization entrypoint
// This must be loaded BEFORE any other scripts that use Leaflet (e.g., decidim_map, awesome_map)
// to ensure all modules share the same Leaflet instance with plugins properly attached.

// Import leaflet_setup FIRST - it sets window.L before any plugins are loaded
// ES6 imports are executed in order, and leaflet_setup.js will run completely
// before the subsequent plugin imports are evaluated
import "src/decidim/leaflet_global";

// Import plugins AFTER leaflet_setup - they will extend the global window.L
import "leaflet.markercluster";
import "leaflet.featuregroup.subgroup";
import "leaflet-tilelayer-here";
