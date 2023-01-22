# frozen_string_literal: true

namespace :delete do
  desc "Destroy all comments for a given organization"
  task destroy_all_comments: :environment do
    puts "Start destroy_all_comments of #{ENV["DECIDIM_ORGANIZATION_NAME"]}"

    organization = Decidim::Organization.find_by(name: ENV["DECIDIM_ORGANIZATION_NAME"])

    unless organization
      puts "Organization not found: '#{ENV["DECIDIM_ORGANIZATION_NAME"]}'"
      puts "Usage: DECIDIM_ORGANIZATION_NAME=<organization name> rails delete::destroy_all_comments"
      return
    end

    Decidim::Comments::Comment.transaction do
      Decidim::Comments::DestroyAllComments.call(organization)
    end

    puts "Finish destroy_all_comments of #{ENV["DECIDIM_ORGANIZATION_NAME"]}"
  end
end
