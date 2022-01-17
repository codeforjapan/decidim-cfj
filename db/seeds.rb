# frozen_string_literal: true

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)
# You can remove the 'faker' gem if you don't want Decidim seeds.

require_relative "../lib/monkey_patching_faker"

# Seeds of DecidimAwesome 0.7.0 and 0.7.2 support Faker 2.x, not 1.9.x.
# So Decidim 0.23.5 (using Faker 1.9.6) should ignore seeds of them.
#
map_component = Decidim.find_component_manifest("awesome_map")
map_component.seeds do |participatory_space|
  # noop
end

iframe_component = Decidim.find_component_manifest("awesome_iframe")
iframe_component.seeds do |participatory_space|
  # noop
end

Decidim.seed!

if !Rails.env.production? || ENV["SEED"]
  print "Creating seeds for decidim-cfj...\n" unless Rails.env.test?

  require "decidim/faker/localized"

  Decidim::User.find_each do |user|
    user_extension = {
      real_name: "#{user.name}_実名",
      address: Faker::Lorem.words(4).join(""),
      gender: [0, 1, 2].sample,
      birth_year: (1980..2010).to_a.sample,
      occupation: ["会社員", "学生", "公務員", "自営業", "無職", nil].sample
    }
    Decidim::Authorization.create!(
      user: user,
      name: "user_extension",
      metadata: user_extension
    )
  end
end
