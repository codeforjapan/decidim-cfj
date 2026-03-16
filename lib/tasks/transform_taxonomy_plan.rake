# frozen_string_literal: true

# Intermediate level prefix patterns used by the category migration tool.
# "参加スペース:" for assemblies, "参加型プロセス:" for participatory processes, etc.
INTERMEDIATE_PREFIXES = /\A(参加スペース|参加型プロセス|Assembly|Participatory process|Conference|Initiative): /

namespace :decidim do
  namespace :taxonomies do
    desc "Transform category taxonomy plan to flatten intermediate levels (one root per participatory space)"
    task :flatten_category_plan, [:file] => :environment do |_task, args|
      file = args[:file].to_s
      abort "File not found! [#{file}]" unless File.exist?(file)

      data = JSON.parse(File.read(file))
      categories_section = data.dig("imported_taxonomies", "decidim_categories")

      unless categories_section
        puts "No decidim_categories section found in plan. Nothing to transform."
        next
      end

      new_categories = {}
      collisions = Hash.new { |hash, key| hash[key] = [] }

      categories_section.each do |_root_name, root_data|
        taxonomies = root_data["taxonomies"] || {}
        filters = root_data["filters"] || []

        taxonomies.each do |intermediate_name, intermediate_data|
          new_root_name = intermediate_name.sub(INTERMEDIATE_PREFIXES, "カテゴリ: ")
          collisions[new_root_name] << intermediate_name

          children = intermediate_data["children"] || {}
          matching_filter = filters.find { |f| f["internal_name"] == intermediate_name }

          new_filter_items = []
          if matching_filter
            (matching_filter["items"] || []).each do |item_path|
              new_path = item_path[1..]
              new_filter_items << new_path if new_path.any?
            end
          end

          new_filter = {
            "name" => new_root_name,
            "items" => new_filter_items,
            "components" => matching_filter&.dig("components") || []
          }

          if matching_filter&.dig("participatory_space_manifests")
            new_filter["participatory_space_manifests"] = matching_filter["participatory_space_manifests"]
          end

          next if new_categories.key?(new_root_name)

          new_categories[new_root_name] = {
            "taxonomies" => children,
            "filters" => [new_filter]
          }
        end
      end

      duplicated_roots = collisions.select { |_name, sources| sources.uniq.size > 1 }
      if duplicated_roots.any?
        puts "ERROR: Duplicate root names detected after flattening. Aborting to avoid data loss:"
        duplicated_roots.each do |new_root_name, sources|
          puts "  - #{new_root_name}"
          sources.uniq.each { |source| puts "      from: #{source}" }
        end
        puts ""
        puts "Please rename conflicting participatory spaces or adjust the plan manually."
        abort "Flattening aborted due to duplicate root names."
      end

      data["imported_taxonomies"]["decidim_categories"] = new_categories

      output_path = file.sub(/_plan\.json$/, "_plan_flattened.json")
      File.write(output_path, JSON.pretty_generate(data))

      puts "Transformed plan written to: #{output_path}"
      puts ""
      puts "New root taxonomies for categories:"
      new_categories.each do |name, root_data|
        taxonomies = root_data["taxonomies"] || {}
        filters = root_data["filters"] || []
        puts "  Root: #{name}"
        puts "    Taxonomies: #{taxonomies.size}"
        taxonomies.each do |tax_name, tax_data|
          children_count = (tax_data["children"] || {}).size
          puts "      - #{tax_name} (children: #{children_count})"
        end
        filters.each do |f|
          puts "    Filter items: #{(f["items"] || []).size}"
          (f["items"] || []).first(3).each { |item| puts "      #{item.inspect}" }
          remaining = (f["items"] || []).size - 3
          puts "      ... and #{remaining} more" if remaining.positive?
        end
      end

      puts ""
      puts "To import: bin/rails decidim:taxonomies:import_plan[#{output_path}]"
    end

    desc "Check for potential issues before flattening imported category taxonomies (dry run)"
    task :check_flatten_imported_categories, [:organization_id] => :environment do |_task, args|
      logger = Logger.new($stdout, formatter: proc { |_severity, _time, _progname, msg| "#{msg}\n" })
      organizations = target_organizations(args[:organization_id])
      has_issues = false

      organizations.each do |organization|
        locale = organization.default_locale
        logger.info "=== Organization: #{organization.name[locale]} (id: #{organization.id}, host: #{organization.host}) ==="

        category_roots = find_category_roots(organization)
        if category_roots.empty?
          logger.info "  No category root taxonomy (\"~ カテゴリ\" / \"~ Categories\") found. Nothing to flatten."
          next
        end

        new_root_names_map = Hash.new { |hash, key| hash[key] = [] }

        category_roots.each do |old_root|
          logger.info "  Category root: #{old_root.name[locale]} (id: #{old_root.id})"

          intermediates = old_root.children.to_a
          if intermediates.empty?
            logger.info "    No intermediate levels (children). Nothing to flatten."
            next
          end

          intermediates.each do |intermediate|
            categories = intermediate.children
            new_root_name_value = intermediate.name[locale]&.sub(INTERMEDIATE_PREFIXES, "カテゴリ: ")
            new_root_names_map[new_root_name_value] << intermediate

            # Check 1: Does the intermediate name match expected pattern?
            unless intermediate.name[locale]&.match?(INTERMEDIATE_PREFIXES)
              has_issues = true
              logger.info "    [WARNING] Intermediate \"#{intermediate.name[locale]}\" (id: #{intermediate.id}) does not match expected prefix pattern"
              logger.info "              Expected: \"参加スペース: ...\" or \"参加型プロセス: ...\""
              logger.info "              This taxonomy will still be processed but the new root name may be unexpected: \"#{new_root_name_value}\""
            end

            # Check 2: Would the new root name collide with an existing root?
            existing_root = organization.taxonomies.roots.find_by("name->>? = ?", locale, new_root_name_value)
            if existing_root
              has_issues = true
              logger.info "    [ERROR] New root name \"#{new_root_name_value}\" already exists (id: #{existing_root.id})"
              logger.info "            This would cause a conflict. Resolve before running flatten."
            end

            # Check 3: Filters matched?
            filters = Decidim::TaxonomyFilter.where(root_taxonomy_id: old_root.id).select do |f|
              f.internal_name[locale] == intermediate.name[locale]
            end
            if filters.empty?
              has_issues = true
              logger.info "    [WARNING] No TaxonomyFilter found matching intermediate \"#{intermediate.name[locale]}\""
              logger.info "              Filter items and component assignments may be lost."
            end

            # Summary
            logger.info "    Intermediate: #{intermediate.name[locale]} (id: #{intermediate.id})"
            logger.info "      -> New root: #{new_root_name_value}"
            logger.info "      Categories to move: #{categories.count}"
            categories.each do |cat|
              subcats = cat.children.count
              logger.info "        - #{cat.name[locale]} (id: #{cat.id}, subcategories: #{subcats})"
            end
            logger.info "      Filters to move: #{filters.size}"
            filters.each do |f|
              logger.info "        - #{f.internal_name[locale]} (id: #{f.id}, items: #{f.filter_items.count}, components: #{f.components_count})"
            end
          end
        end

        duplicated_new_roots = new_root_names_map.select { |_name, intermediates| intermediates.size > 1 }
        duplicated_new_roots.each do |new_name, intermediates|
          has_issues = true
          logger.info "    [ERROR] Duplicate new root name detected: \"#{new_name}\""
          logger.info "            The following intermediates would collide:"
          intermediates.each do |intermediate|
            logger.info "              - #{intermediate.name[locale]} (id: #{intermediate.id})"
          end
          logger.info "            Flattening would skip data for some intermediates. Resolve before running flatten."
        end

        logger.info ""
      end

      if has_issues
        logger.info "=== Issues found. Please review warnings/errors above before running flatten. ==="
      else
        logger.info "=== No issues found. Safe to run: bin/rails decidim:taxonomies:flatten_imported_categories ==="
      end
    end

    desc "Fix already-imported category taxonomies by flattening intermediate levels. " \
         "Optionally specify organization_id, e.g. decidim:taxonomies:flatten_imported_categories[42]"
    task :flatten_imported_categories, [:organization_id] => :environment do |_task, args|
      logger = Logger.new($stdout, formatter: proc { |_severity, _time, _progname, msg| "#{msg}\n" })
      organizations = target_organizations(args[:organization_id])

      organizations.each do |organization|
        locale = organization.default_locale
        logger.info "Processing organization: #{organization.name[locale]} (id: #{organization.id}, host: #{organization.host})"

        category_roots = find_category_roots(organization)
        if category_roots.empty?
          logger.info "  No category root taxonomy found. Skipping."
          next
        end

        new_root_names_map = Hash.new { |hash, key| hash[key] = [] }
        category_roots.each do |old_root|
          old_root.children.each do |intermediate|
            new_root_name_value = intermediate.name[locale]&.sub(INTERMEDIATE_PREFIXES, "カテゴリ: ")
            new_root_names_map[new_root_name_value] << intermediate
          end
        end
        duplicated_new_roots = new_root_names_map.select { |_name, intermediates| intermediates.size > 1 }
        if duplicated_new_roots.any?
          logger.error "  ERROR: Duplicate new root names detected. Aborting flatten for this organization."
          duplicated_new_roots.each do |new_name, intermediates|
            logger.error "    - #{new_name}"
            intermediates.each do |intermediate|
              logger.error "        from intermediate: #{intermediate.name[locale]} (id: #{intermediate.id})"
            end
          end
          logger.error "  Resolve naming collisions and rerun."
          next
        end

        category_roots.each do |old_root|
          logger.info "  Found category root: #{old_root.name[locale]} (id: #{old_root.id})"

          intermediates = old_root.children.to_a
          if intermediates.empty?
            logger.info "    No intermediate levels found. Skipping."
            next
          end

          intermediates.each do |intermediate|
            logger.info "    Processing intermediate: #{intermediate.name[locale]} (id: #{intermediate.id})"

            new_root_name = intermediate.name.transform_values do |name|
              name.sub(INTERMEDIATE_PREFIXES, "カテゴリ: ")
            end

            # Check for name collision
            existing = organization.taxonomies.roots.find_by("name->>? = ?", locale, new_root_name[locale])
            if existing
              logger.warn "    ERROR: Root taxonomy \"#{new_root_name[locale]}\" already exists (id: #{existing.id}). Skipping this intermediate."
              next
            end

            new_root = Decidim::Taxonomy.create!(
              name: new_root_name,
              organization: organization,
              weight: Decidim::Taxonomy.where(parent_id: nil, decidim_organization_id: organization.id).count
            )
            logger.info "    Created new root: #{new_root.name[locale]} (id: #{new_root.id})"

            categories = intermediate.children.to_a
            categories.each do |category|
              category.update!(parent: new_root)
              logger.info "      Moved category: #{category.name[locale]} (id: #{category.id})"
              update_descendants_part_of(category)
            end

            filters = Decidim::TaxonomyFilter.where(root_taxonomy_id: old_root.id).select do |f|
              f.internal_name[locale] == intermediate.name[locale]
            end

            filters.each do |filter|
              filter.update!(root_taxonomy_id: new_root.id)
              logger.info "      Moved filter: #{filter.internal_name[locale]} (id: #{filter.id}) -> root #{new_root.id}"
            end

            # Delete empty intermediate (reload to clear association cache)
            intermediate.reload
            if intermediate.children.count.zero?
              intermediate.destroy!
              logger.info "    Deleted intermediate: #{intermediate.name[locale]}"
            else
              logger.warn "    WARNING: Intermediate still has children, not deleting: #{intermediate.name[locale]}"
            end
          end

          # Delete old root if empty
          old_root.reload
          if old_root.children.count.zero?
            remaining_filters = Decidim::TaxonomyFilter.where(root_taxonomy_id: old_root.id)
            if remaining_filters.any?
              logger.warn "  WARNING: Old root still has #{remaining_filters.count} filters. Not deleting."
            else
              old_root.destroy!
              logger.info "  Deleted old root: #{old_root.name[locale]}"
            end
          else
            logger.warn "  WARNING: Old root still has children, not deleting: #{old_root.name[locale]}"
          end
        end

        # Reset counters
        logger.info "  Resetting taxonomy counters..."
        Decidim::Taxonomy.where(decidim_organization_id: organization.id).find_each(&:reset_all_counters)
        Decidim::TaxonomyFilter.joins(:root_taxonomy)
                               .where(decidim_taxonomies: { decidim_organization_id: organization.id })
                               .find_each(&:reset_all_counters)

        logger.info "  Done."
      end
    end
  end
end

def target_organizations(organization_id)
  if organization_id.present?
    org = Decidim::Organization.find_by(id: organization_id)
    abort "Organization not found: #{organization_id}" unless org
    [org]
  else
    Decidim::Organization.order(:id).to_a
  end
end

def find_category_roots(organization)
  locale = organization.default_locale
  categories_title = I18n.t("decidim.admin.categories.index.categories_title", locale: locale, default: "Categories")
  organization.taxonomies.roots.select do |root|
    name = root.name[locale]
    name&.start_with?("~ カテゴリ") ||
      name&.start_with?("~ #{categories_title}")
  end
end

def update_descendants_part_of(taxonomy)
  taxonomy.children.each do |child|
    child.save! # triggers build_part_of via before_validation
    update_descendants_part_of(child)
  end
end
