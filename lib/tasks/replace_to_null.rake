# frozen_string_literal: true

namespace :replace_to_null do
  desc "fix space edit bug.Make all announcement columns of decidim_assemblies table null"
  task decidim_assemblies_announcement: :environment do
    Decidim::Assembly.update_all(announcement: nil) # rubocop:disable Rails/SkipsModelValidations
  end
end
