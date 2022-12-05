# frozen_string_literal: true

module Decidim
  module Map
    module Provider
      module StaticMap
        class CfjOsm < ::Decidim::Map::StaticMap
          # Tile Source
          class TileSource
            attr_reader :url, :organization

            def initialize(url, organization)
              @url = url
              @organization = organization
            end

            def get_tiles(tiles)
              tiles.map do |tile|
                request_url = tile_url(tile)
                response = Faraday.get(request_url) do |req|
                  req.headers["Referer"] = organization.host
                end

                response.body
              end
            end

            private

            attr_reader :connection

            def tile_url(tile)
              url
                .gsub(/\{x\}/, tile.x.to_s)
                .gsub(/\{y\}/, tile.y.to_s)
                .gsub(/\{z\}/, tile.zoom.to_s)
                .gsub(/\{s\}/, subdomain_for_tile(tile))
            end

            def subdomain_for_tile(tile)
              i = (tile.x + tile.y) % subdomains.length
              subdomains[i]
            end

            def subdomains
              %w(a b c)
            end
          end
        end
      end
    end
  end
end
