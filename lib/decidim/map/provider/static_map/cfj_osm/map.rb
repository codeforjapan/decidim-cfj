# frozen_string_literal: true

require 'mini_magick'

require_relative 'conversion'
require_relative 'tile_source'
require_relative 'bounding_box'

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
                :bbox => bounding_box.to_s,
                :width => width.to_i,
                :height => height.to_i,
                :zoom => zoom,
                :number_of_tiles => required_tiles.length,
              }
            end

            private

            def bounding_box
              @bounding_box ||= BoundingBox.new(lng: lng, lat: lat, width: width, height: height, zoom: zoom)
            end

            def required_x_tiles
              Range.new(*[bounding_box.in_tiles_left, bounding_box.in_tiles_right].map(&:floor)).to_a
            end

            def required_y_tiles
              Range.new(*[bounding_box.in_tiles_top, bounding_box.in_tiles_bottom].map(&:floor)).to_a
            end

            def required_tiles
              required_y_tiles.map do |y|
                required_x_tiles.map{|x| Tile.new(x: x.floor, y: y.floor, zoom: zoom) }
              end.flatten
            end

            def crop_to_size(image)
              distance_from_left = (bounding_box.in_tiles_left - required_x_tiles[0]) * TILE_SIZE
              distance_from_top  = (bounding_box.in_tiles_top - required_y_tiles[0]) * TILE_SIZE

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
