# frozen_string_literal: true

require "decidim/cfj/taxonomy_flatten_constants"

module Decidim
  module Cfj
    class TaxonomyFlattener
      attr_reader :issues

      def initialize(organization, logger: Rails.logger)
        @organization = organization
        @locale = organization.default_locale
        @logger = logger
        @issues = []
      end

      def check!
        @issues = []
        Checker.new(@organization, @locale, @logger, @issues).run
      end

      def flatten!
        @issues = []
        Executor.new(@organization, @locale, @logger, @issues).run
      end

      # 共通基盤: クエリ・走査・issue追跡
      class Base
        include TaxonomyFlattenConstants

        def initialize(organization, locale, logger, issues)
          @organization = organization
          @locale = locale
          @logger = logger
          @issues = issues
        end

        private

        def add_issue(level, message, detail: nil)
          @issues << { level: level, message: message }
          tag = level == :error ? "ERROR" : "WARNING"
          @logger.info "    [#{tag}] #{message}"
          @logger.info "            #{detail}" if detail
        end

        def prepare_roots
          category_roots = find_category_roots
          if category_roots.empty?
            @logger.info "  No category root taxonomy found. Nothing to flatten."
            return nil
          end
          [category_roots, build_collision_map(category_roots)]
        end

        def each_intermediate(category_roots)
          category_roots.each do |old_root|
            @logger.info "  Category root: #{old_root.name[@locale]} (id: #{old_root.id})"
            intermediates = old_root.children.to_a
            if intermediates.empty?
              @logger.info "    No intermediate levels. Skipping."
              next
            end
            intermediates.each { |intermediate| yield(old_root, intermediate) }
          end
        end

        def find_category_roots
          categories_title = I18n.t("decidim.admin.categories.index.categories_title", locale: @locale, default: "Categories")
          @organization.taxonomies.roots.select do |root|
            name = root.name[@locale]
            name&.start_with?("~ カテゴリ") ||
              name&.start_with?("~ #{categories_title}")
          end
        end

        def compute_new_root_name(name)
          name.sub(INTERMEDIATE_PREFIXES, "カテゴリ: ")
        end

        def build_collision_map(category_roots)
          map = Hash.new { |hash, key| hash[key] = [] }
          category_roots.each do |old_root|
            old_root.children.each do |intermediate|
              new_root_name_value = compute_new_root_name(intermediate.name[@locale].to_s)
              map[new_root_name_value] << intermediate
            end
          end
          map
        end

        def find_filters_for(old_root, intermediate)
          old_root.taxonomy_filters.select do |f|
            f.internal_name[@locale] == intermediate.name[@locale]
          end
        end

        def find_existing_root(new_root_name_value)
          @organization.taxonomies.roots.find_by("name->>? = ?", @locale, new_root_name_value)
        end

        def report_collisions(collision_map)
          duplicated = collision_map.select { |_name, intermediates| intermediates.size > 1 }
          duplicated.each do |new_name, intermediates|
            names = intermediates.map { |i| "#{i.name[@locale]} (id: #{i.id})" }.join(", ")
            add_issue(:error, "Duplicate new root name: \"#{new_name}\"",
                      detail: "Colliding intermediates: #{names}")
          end
          duplicated
        end
      end

      # read-only分析
      class Checker < Base
        def run
          result = prepare_roots
          return true unless result

          category_roots, collision_map = result
          each_intermediate(category_roots) { |old_root, intermediate| check_intermediate(old_root, intermediate) }
          report_collisions(collision_map)

          @issues.empty?
        end

        private

        def check_intermediate(old_root, intermediate)
          new_root_name_value = compute_new_root_name(intermediate.name[@locale].to_s)

          unless intermediate.name[@locale]&.match?(INTERMEDIATE_PREFIXES)
            add_issue(:warning, "Intermediate \"#{intermediate.name[@locale]}\" (id: #{intermediate.id}) does not match expected prefix pattern",
                      detail: "New root name may be unexpected: \"#{new_root_name_value}\"")
          end

          existing = find_existing_root(new_root_name_value)
          if existing
            add_issue(:error, "New root name \"#{new_root_name_value}\" already exists (id: #{existing.id})",
                      detail: "This would cause a conflict. Resolve before running flatten.")
          end

          filters = find_filters_for(old_root, intermediate)
          if filters.empty?
            add_issue(:warning, "No TaxonomyFilter found matching intermediate \"#{intermediate.name[@locale]}\"",
                      detail: "Filter items and component assignments may be lost.")
          end

          categories = intermediate.children
          @logger.info "    Intermediate: #{intermediate.name[@locale]} (id: #{intermediate.id})"
          @logger.info "      -> New root: #{new_root_name_value}"
          @logger.info "      Categories to move: #{categories.count}"
          categories.each do |cat|
            @logger.info "        - #{cat.name[@locale]} (id: #{cat.id}, subcategories: #{cat.children.count})"
          end
          @logger.info "      Filters to move: #{filters.size}"
          filters.each do |f|
            @logger.info "        - #{f.internal_name[@locale]} (id: #{f.id}, items: #{f.filter_items.count}, components: #{f.components_count})"
          end
        end
      end

      # DB変更の実行
      class Executor < Base
        def run
          result = prepare_roots
          return unless result

          category_roots, collision_map = result
          unless report_collisions(collision_map).empty?
            @logger.error "  Aborting flatten for this organization. Resolve naming collisions and rerun."
            return
          end

          each_intermediate(category_roots) { |old_root, intermediate| flatten_intermediate(old_root, intermediate) }
          category_roots.each { |old_root| cleanup_old_root(old_root) }
          reset_counters
          @logger.info "  Done."
        end

        private

        def flatten_intermediate(old_root, intermediate)
          @logger.info "    Processing intermediate: #{intermediate.name[@locale]} (id: #{intermediate.id})"

          new_root_name = intermediate.name.transform_values { |name| name.sub(INTERMEDIATE_PREFIXES, "カテゴリ: ") }

          existing = find_existing_root(new_root_name[@locale])
          if existing
            add_issue(:error, "Root taxonomy \"#{new_root_name[@locale]}\" already exists (id: #{existing.id}). Skipping.")
            return
          end

          new_root = Decidim::Taxonomy.create!(
            name: new_root_name,
            organization: @organization,
            weight: @organization.taxonomies.roots.count
          )
          @logger.info "    Created new root: #{new_root.name[@locale]} (id: #{new_root.id})"

          move_categories(intermediate, new_root)
          move_filters(old_root, intermediate, new_root)
          cleanup_intermediate(intermediate)
        end

        def move_categories(intermediate, new_root)
          intermediate.children.to_a.each do |category|
            category.update!(parent: new_root)
            @logger.info "      Moved category: #{category.name[@locale]} (id: #{category.id})"
            update_descendants_part_of(category)
          end
        end

        def move_filters(old_root, intermediate, new_root)
          find_filters_for(old_root, intermediate).each do |filter|
            filter.update!(root_taxonomy_id: new_root.id)
            @logger.info "      Moved filter: #{filter.internal_name[@locale]} (id: #{filter.id}) -> root #{new_root.id}"
          end
        end

        def cleanup_intermediate(intermediate)
          intermediate.reload
          if intermediate.children.count.zero?
            intermediate.destroy!
            @logger.info "    Deleted intermediate: #{intermediate.name[@locale]}"
          else
            @logger.warn "    WARNING: Intermediate still has children, not deleting: #{intermediate.name[@locale]}"
          end
        end

        def cleanup_old_root(old_root)
          old_root.reload
          if old_root.children.count.zero?
            remaining_filters = old_root.taxonomy_filters
            if remaining_filters.any?
              @logger.warn "  WARNING: Old root still has #{remaining_filters.count} filters. Not deleting."
            else
              old_root.destroy!
              @logger.info "  Deleted old root: #{old_root.name[@locale]}"
            end
          else
            @logger.warn "  WARNING: Old root still has children, not deleting: #{old_root.name[@locale]}"
          end
        end

        def update_descendants_part_of(taxonomy)
          taxonomy.children.each do |child|
            child.save!
            update_descendants_part_of(child)
          end
        end

        def reset_counters
          @logger.info "  Resetting taxonomy counters..."
          @organization.taxonomies.find_each(&:reset_all_counters)
          Decidim::TaxonomyFilter.where(root_taxonomy: @organization.taxonomies.roots)
                                 .find_each(&:reset_all_counters)
        end
      end
    end
  end
end
