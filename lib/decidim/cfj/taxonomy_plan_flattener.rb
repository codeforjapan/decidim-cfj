# frozen_string_literal: true

require "decidim/cfj/taxonomy_flatten_constants"

module Decidim
  module Cfj
    class TaxonomyPlanFlattener
      include TaxonomyFlattenConstants

      class CollisionError < StandardError; end

      Entry = Struct.new(:original_name, :new_root_name, :children, :filter_data, keyword_init: true)

      attr_reader :result, :summary

      def initialize(data)
        categories_section = data.dig("imported_taxonomies", "decidim_categories")
        unless categories_section
          @result = data
          @summary = {}
          return
        end

        new_categories = flatten_categories(categories_section)
        @result = data.merge(
          "imported_taxonomies" => data["imported_taxonomies"].merge("decidim_categories" => new_categories)
        )
        @summary = build_summary(new_categories)
      end

      private

      def flatten_categories(categories_section)
        entries = categories_section.each_value.flat_map { |root_data| collect_entries(root_data) }
        detect_collisions!(entries)
        assemble_categories(entries)
      end

      def collect_entries(root_data)
        taxonomies = root_data["taxonomies"] || {}
        filters = root_data["filters"] || []

        taxonomies.map do |intermediate_name, intermediate_data|
          new_root_name = compute_new_root_name(intermediate_name)
          matching_filter = filters.find { |f| f["internal_name"] == intermediate_name }

          Entry.new(
            original_name: intermediate_name,
            new_root_name: new_root_name,
            children: intermediate_data["children"] || {},
            filter_data: build_filter(new_root_name, matching_filter)
          )
        end
      end

      def assemble_categories(entries)
        entries.each_with_object({}) do |entry, hash|
          next if hash.has_key?(entry.new_root_name)

          hash[entry.new_root_name] = {
            "taxonomies" => entry.children,
            "filters" => [entry.filter_data]
          }
        end
      end

      def compute_new_root_name(name)
        name.sub(INTERMEDIATE_PREFIXES, "カテゴリ: ")
      end

      def build_filter(new_root_name, matching_filter)
        new_filter_items = if matching_filter
                             (matching_filter["items"] || []).filter_map do |item_path|
                               new_path = item_path[1..]
                               new_path if new_path&.any?
                             end
                           else
                             []
                           end

        new_filter = {
          "name" => new_root_name,
          "items" => new_filter_items,
          "components" => matching_filter&.dig("components") || []
        }

        new_filter["participatory_space_manifests"] = matching_filter["participatory_space_manifests"] if matching_filter&.dig("participatory_space_manifests")

        new_filter
      end

      def detect_collisions!(entries)
        grouped = entries.group_by(&:new_root_name)
        duplicated = grouped.select { |_, group| group.map(&:original_name).uniq.size > 1 }
        return if duplicated.empty?

        messages = duplicated.map do |new_root_name, group|
          sources = group.map(&:original_name).uniq
          "  - #{new_root_name}\n" + sources.map { |s| "      from: #{s}" }.join("\n")
        end

        raise CollisionError,
              "Duplicate root names detected after flattening:\n#{messages.join("\n")}\nPlease rename conflicting participatory spaces or adjust the plan manually."
      end

      def build_summary(new_categories)
        new_categories.each_with_object({}) do |(name, root_data), summary|
          taxonomies = root_data["taxonomies"] || {}
          filters = root_data["filters"] || []
          filter_items_count = filters.sum { |f| (f["items"] || []).size }

          summary[name] = {
            taxonomies: taxonomies.map do |tax_name, tax_data|
              { name: tax_name, children_count: (tax_data["children"] || {}).size }
            end,
            filter_items_count: filter_items_count
          }
        end
      end
    end
  end
end
