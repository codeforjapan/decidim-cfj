# frozen_string_literal: true

module Decidim
  module Map
    module Provider
      module StaticMap
        class CfjOsm < ::Decidim::Map::StaticMap
          class BoundingBox
            TILE_SIZE = 256

            attr_reader :lng, :lat, :width, :height, :zoom
            attr_reader :left, :right, :top, :bottom

            def initialize(lng:, lat:, width:, height:, zoom:)
              @lng = lng
              @lat = lat
              @width = width
              @height = height
              @zoom = zoom

              @left = Conversion.x_to_lng( to_x - ((width / TILE_SIZE) / 2), zoom)
              @right = Conversion.x_to_lng( to_x + ((width / TILE_SIZE) / 2 ), zoom)
              @top = Conversion.y_to_lat( to_y - ((height / TILE_SIZE) / 2 ), zoom)
              @bottom = Conversion.y_to_lat( to_y + ((height / TILE_SIZE) / 2 ), zoom)
            end

            def in_tiles_left
              Conversion.lng_to_x(left, zoom)
            end

            def in_tiles_right
              Conversion.lng_to_x(right, zoom)
            end

            def in_tiles_bottom
              Conversion.lat_to_y(bottom, zoom)
            end

            def in_tiles_top
              Conversion.lat_to_y(top, zoom)
            end

            def to_s
              [left, right, top, bottom].join(',')
            end

            private

            def to_x
              Conversion.lng_to_x(lng, zoom)
            end

            def to_y
              Conversion.lat_to_y(lat, zoom)
            end
          end
        end
      end
    end
  end
end
