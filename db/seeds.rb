# frozen_string_literal: true

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)
# You can remove the 'faker' gem if you don't want Decidim seeds.

Decidim.seed!

if !Rails.env.production? || ENV.fetch("SEED")
  print "Creating seeds for decidim-cfj...\n" unless Rails.env.test?

  require "decidim/faker/localized"

  Decidim::User.find_each do |user|
    user_extension = {
      real_name: "#{user.name}_実名",
      address: Faker::Lorem.words(number: 4).join,
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
