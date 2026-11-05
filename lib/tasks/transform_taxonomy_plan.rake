# frozen_string_literal: true

require "decidim/cfj/taxonomy_plan_flattener"
require "decidim/cfj/taxonomy_flattener"

def target_organizations(organization_id)
  if organization_id.present?
    org = Decidim::Organization.find_by(id: organization_id)
    abort "Organization not found: #{organization_id}" unless org
    [org]
  else
    Decidim::Organization.order(:id).to_a
  end
end

namespace :decidim do
  namespace :taxonomies do
    desc "カテゴリ分類プランの中間レベルをフラット化する（参加スペースごとに1ルート）"
    task :flatten_category_plan, [:file] => :environment do |_task, args|
      file = args[:file].to_s
      abort "File not found! [#{file}]" unless File.exist?(file)

      data = JSON.parse(File.read(file))

      unless data.dig("imported_taxonomies", "decidim_categories")
        puts "No decidim_categories section found in plan. Nothing to transform."
        next
      end

      begin
        flattener = Decidim::Cfj::TaxonomyPlanFlattener.new(data)
      rescue Decidim::Cfj::TaxonomyPlanFlattener::CollisionError => e
        puts "ERROR: #{e.message}"
        abort "Flattening aborted due to duplicate root names."
      end

      output_path = file.sub(/_plan\.json$/, "_plan_flattened.json")
      File.write(output_path, JSON.pretty_generate(flattener.result))

      puts "Transformed plan written to: #{output_path}"
      puts ""
      puts "New root taxonomies for categories:"
      flattener.summary.each do |name, info|
        puts "  Root: #{name}"
        puts "    Taxonomies: #{info[:taxonomies].size}"
        info[:taxonomies].each do |tax|
          puts "      - #{tax[:name]} (children: #{tax[:children_count]})"
        end
        puts "    Filter items: #{info[:filter_items_count]}"
      end

      puts ""
      puts "To import: bin/rails decidim:taxonomies:import_plan[#{output_path}]"
    end

    desc "インポート済みカテゴリ分類のフラット化事前チェック（dry run）"
    task :check_flatten_imported_categories, [:organization_id] => :environment do |_task, args|
      logger = Logger.new($stdout, formatter: proc { |_severity, _time, _progname, msg| "#{msg}\n" })
      organizations = target_organizations(args[:organization_id])
      has_issues = false

      organizations.each do |organization|
        locale = organization.default_locale
        logger.info "=== Organization: #{organization.name[locale]} (id: #{organization.id}, host: #{organization.host}) ==="

        flattener = Decidim::Cfj::TaxonomyFlattener.new(organization, logger: logger)
        result = flattener.check!
        has_issues = true unless result

        logger.info ""
      end

      if has_issues
        logger.info "=== Issues found. Please review warnings/errors above before running flatten. ==="
      else
        logger.info "=== No issues found. Safe to run: bin/rails decidim:taxonomies:flatten_imported_categories ==="
      end
    end

    desc "インポート済みカテゴリ分類の中間レベルをフラット化する。organization_id指定可: decidim:taxonomies:flatten_imported_categories[42]"
    task :flatten_imported_categories, [:organization_id] => :environment do |_task, args|
      logger = Logger.new($stdout, formatter: proc { |_severity, _time, _progname, msg| "#{msg}\n" })
      organizations = target_organizations(args[:organization_id])

      organizations.each do |organization|
        locale = organization.default_locale
        logger.info "Processing organization: #{organization.name[locale]} (id: #{organization.id}, host: #{organization.host})"

        flattener = Decidim::Cfj::TaxonomyFlattener.new(organization, logger: logger)
        flattener.flatten!
      end
    end
  end
end
