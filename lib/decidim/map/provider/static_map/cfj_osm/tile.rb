module Decidim
  module Map
    module Provider
      module StaticMap
        class CfjOsm < ::Decidim::Map::StaticMap
          class Tile
            attr_accessor :x, :y, :zoom

            def initialize(x, y, zoom)
              @x = x.floor
              @y = y.floor
              @zoom = zoom
            end
          end
        end
      end
    end
  end
end
