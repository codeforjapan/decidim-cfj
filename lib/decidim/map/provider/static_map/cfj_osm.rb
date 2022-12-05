# frozen_string_literal: true

require_relative 'cfj_osm/map'

module Decidim
  module Map
    module Provider
      module StaticMap
        # The static map utility class based on Osm
        class CfjOsm < ::Decidim::Map::StaticMap
          def image_data(latitude:, longitude:, options: {})

            zoom = options[:zoom] || 15
            width = options[:width] || 120
            height = options[:height] || 120

            Rails.logger.info("######################image_data###############")
            Rails.logger.info([latitude, longitude, zoom, width, height])

            map = ::Decidim::Map::Provider::StaticMap::CfjOsm::Map.new(
              zoom: zoom,
              lat: latitude,
              lng: longitude,
              width: width,
              height: height,
              provider: 'http://tile.openstreetmap.jp/{z}/{x}/{y}.png',
              organization: organization
            )

            Dir.mktmpdir do |dir|
              tmpfile = File.join(dir, "map.png")
              map.render_map(tmpfile)

              return File.binread(tmpfile)
            end
          end

          # @See Decidim::Map::StaticMap#url_params
          def url_params(latitude:, longitude:, options: {})
            # This is the format used by osm-static-maps which is not an
            # official OSM product but it should be rather easy to setup. For
            # further information, see:
            # https://github.com/jperelli/osm-static-maps
            {
              geojson: {
                type: "Point",
                coordinates: [longitude, latitude]
              }.to_json,
              zoom: options[:zoom] || 15,
              width: options[:width] || 120,
              height: options[:height] || 120
            }
          end
        end
      end
    end
  end
end
