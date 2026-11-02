# frozen_string_literal: true

# Unlocks the admin panel of a user locked after too many wrong admin login codes.
#
#   bin/rails admin_login_code:unlock DECIDIM_ORGANIZATION_ID=<id> EMAIL=<email>
namespace :admin_login_code do
  desc "Unlock the admin panel of a user (DECIDIM_ORGANIZATION_ID= EMAIL=)"
  task unlock: :environment do
    organization = Decidim::Organization.find_by(id: ENV.fetch("DECIDIM_ORGANIZATION_ID", nil))
    abort "Organization not found: #{ENV.fetch("DECIDIM_ORGANIZATION_ID", nil)}" unless organization

    user = Decidim::User.find_by(organization:, email: ENV.fetch("EMAIL", "").downcase)
    abort "User not found: #{ENV.fetch("EMAIL", nil)}" unless user

    login_code = Decidim::AdminLoginCode.find_by(user:)
    abort "The admin panel of #{user.email} is not locked" unless login_code&.locked?

    Decidim::AdminLoginCode.unlock!(user)
    puts "Unlocked the admin panel of #{user.email} (organization #{organization.id})"
  end
end
