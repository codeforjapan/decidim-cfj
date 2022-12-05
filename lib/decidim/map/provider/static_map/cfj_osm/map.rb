# frozen_string_literal: true

require_relative 'conversion'
require_relative 'tile_source'

module Decidim
  module Map
    module Provider
      module StaticMap
        class CfjOsm < ::Decidim::Map::StaticMap

          Tile = Struct.new(:x, :y, :zoom, keyword_init: true)

          # static map generator (cf. https://github.com/crofty/mapstatic)
          class Map
            TILE_SIZE = 256

            attr_reader :zoom, :lat, :lng, :width, :height
            attr_reader :map_tiles

            def initialize(zoom:, lat:, lng:, width:, height:, provider:, organization:)
              @lat    = lat.to_f
              @lng    = lng.to_f
              @width  = width.to_f
              @height = height.to_f
              @zoom = zoom.to_i
              tile_source = TileSource.new(provider, organization)
              @map_tiles = tile_source.get_tiles(required_tiles)
            end

            def width
              @width ||= begin
                           left, bottom, right, top = bounding_box_in_tiles
                           (right - left) * TILE_SIZE
                         end
            end

            def height
              @height ||= begin
                            left, bottom, right, top = bounding_box_in_tiles
                            (bottom - top) * TILE_SIZE
                          end
            end

            def to_image
              base_image = create_uncropped_image
              base_image = fill_image_with_tiles(base_image)
              crop_to_size base_image
              base_image
            end

            def render_map(filename)
              to_image.write filename
            end

            def metadata
              {
                :bbox => bounding_box.join(','),
                :width => width.to_i,
                :height => height.to_i,
                :zoom => zoom,
                :number_of_tiles => required_tiles.length,
              }
            end

            private

            def x_tile_space
              Conversion.lng_to_x(lng, zoom)
            end

            def y_tile_space
              Conversion.lat_to_y(lat, zoom)
            end

            def width_tile_space
              width / TILE_SIZE
            end

            def height_tile_space
              height / TILE_SIZE
            end

            def bounding_box
              @bounding_box ||= begin
                                  left      = Conversion.x_to_lng( x_tile_space - (width_tile_space / 2), zoom)
                                  right     = Conversion.x_to_lng( x_tile_space + ( width_tile_space / 2 ), zoom)
                                  top       = Conversion.y_to_lat( y_tile_space - ( height_tile_space / 2 ), zoom)
                                  bottom    = Conversion.y_to_lat( y_tile_space + ( height_tile_space / 2 ), zoom)

                                  [ left, bottom, right, top ]
                                end
            end

            def bounding_box_in_tiles
              left, bottom, right, top = bounding_box
              [
                Conversion.lng_to_x(left, zoom),
                Conversion.lat_to_y(bottom, zoom),
                Conversion.lng_to_x(right, zoom),
                Conversion.lat_to_y(top, zoom)
              ]
            end

            def required_x_tiles
              left, bottom, right, top = bounding_box_in_tiles
              Range.new(*[left, right].map(&:floor)).to_a
            end

            def required_y_tiles
              left, bottom, right, top = bounding_box_in_tiles
              Range.new(*[top, bottom].map(&:floor)).to_a
            end

            def required_tiles
              required_y_tiles.map do |y|
                required_x_tiles.map{|x| Tile.new(x: x.floor, y: y.floor, zoom: zoom) }
              end.flatten
            end

            def crop_to_size(image)
              distance_from_left = (bounding_box_in_tiles[0] - required_x_tiles[0]) * TILE_SIZE
              distance_from_top  = (bounding_box_in_tiles[3] - required_y_tiles[0]) * TILE_SIZE

              image.crop "#{width}x#{height}+#{distance_from_left}+#{distance_from_top}"
            end

            def create_uncropped_image
              image = MiniMagick::Image.read(map_tiles[0])

              uncropped_width  = required_x_tiles.length * TILE_SIZE
              uncropped_height = required_y_tiles.length * TILE_SIZE

              image.combine_options do |c|
                c.background 'none'
                c.extent [uncropped_width, uncropped_height].join('x')
              end

              image
            end

            def fill_image_with_tiles(image)
              start = 0

              required_y_tiles.length.times do |row|
                length = required_x_tiles.length

                map_tiles.slice(start, length).each_with_index do |tile, column|
                  image = image.composite( MiniMagick::Image.read(tile) ) do |c|
                    c.geometry "+#{ (column) * TILE_SIZE }+#{ (row) * TILE_SIZE }"
                  end
                end

                start += length
              end

              image
            end

          end
        end
      end
    end
  end
end
