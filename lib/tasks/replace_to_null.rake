# frozen_string_literal: true

namespace :replace_to_null do
  desc "fix space edit bug.Make all announcement columns of decidim_assemblies table null"
  task decidim_assemblies_announcement: :environment do
    Decidim::Assembly.update_all(announcement: nil) # rubocop:disable Rails/SkipsModelValidations
  end

  desc 'fix organization edit bug.Make all "" columns of decidim_assemblies table null'
  task decidim_organization: :environment do
    Decidim::Organization.transaction do
      Decidim::Organization.all.each do |org|
        org.description = nil if org.description == ""
        org.highlighted_content_banner_short_description = nil if org.highlighted_content_banner_short_description == ""
        org.save!
      end
    end
  end
end
