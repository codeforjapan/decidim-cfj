# frozen_string_literal: true

namespace :delete do
  desc "Destroy all components for a given organization"
  task destroy_all: [
    :destroy_all_comments,
    :destroy_all_attachments,
    :destroy_all_accountability,
    :destroy_all_budgets,
    :destroy_all_proposals,
    :destroy_all_blogs,
    :destroy_all_debates,
    :destroy_all_meetings,
    :destroy_all_pages
  ]

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

  desc "Destroy all accountability for a given organization"
  task destroy_all_accountability: :environment do
    puts "Start destroy_all_accountability of #{ENV["DECIDIM_ORGANIZATION_NAME"]}"

    organization = Decidim::Organization.find_by(name: ENV["DECIDIM_ORGANIZATION_NAME"])

    unless organization
      puts "Organization not found: '#{ENV["DECIDIM_ORGANIZATION_NAME"]}'"
      puts "Usage: DECIDIM_ORGANIZATION_NAME=<organization name> rails delete::destroy_all_accountability"
      return
    end

    Decidim::Accountability::Result.transaction do
      Decidim::Accountability::DestroyAllResults.call(organization)
    end

    puts "Finish destroy_all_accountability of #{ENV["DECIDIM_ORGANIZATION_NAME"]}"
  end

  desc "Destroy all attachments for a given organization"
  task destroy_all_attachments: :environment do
    puts "Start destroy_all_attachments of #{ENV["DECIDIM_ORGANIZATION_NAME"]}"

    organization = Decidim::Organization.find_by(name: ENV["DECIDIM_ORGANIZATION_NAME"])

    unless organization
      puts "Organization not found: '#{ENV["DECIDIM_ORGANIZATION_NAME"]}'"
      puts "Usage: DECIDIM_ORGANIZATION_NAME=<organization name> rails delete::destroy_all_attachments"
      return
    end

    Decidim::Attachment.transaction do
      Decidim::DestroyAllAttachments.call(organization)
    end

    puts "Finish destroy_all_attachments of #{ENV["DECIDIM_ORGANIZATION_NAME"]}"
  end

  desc "Destroy all budgets for a given organization"
  task destroy_all_budgets: :environment do
    puts "Start destroy_all_budgets of #{ENV["DECIDIM_ORGANIZATION_NAME"]}"

    organization = Decidim::Organization.find_by(name: ENV["DECIDIM_ORGANIZATION_NAME"])

    unless organization
      puts "Organization not found: '#{ENV["DECIDIM_ORGANIZATION_NAME"]}'"
      puts "Usage: DECIDIM_ORGANIZATION_NAME=<organization name> rails delete::destroy_all_budgets"
      return
    end

    Decidim::Budgets::Budget.transaction do
      Decidim::Budgets::DestroyAllBudgets.call(organization)
    end

    puts "Finish destroy_all_budgets of #{ENV["DECIDIM_ORGANIZATION_NAME"]}"
  end

  desc "Destroy all proposals for a given organization"
  task destroy_all_proposals: :environment do
    puts "Start destroy_all_proposals of #{ENV["DECIDIM_ORGANIZATION_NAME"]}"

    organization = Decidim::Organization.find_by(name: ENV["DECIDIM_ORGANIZATION_NAME"])

    unless organization
      puts "Organization not found: '#{ENV["DECIDIM_ORGANIZATION_NAME"]}'"
      puts "Usage: DECIDIM_ORGANIZATION_NAME=<organization name> rails delete::destroy_all_proposals"
      return
    end

    Decidim::Proposals::Proposal.transaction do
      Decidim::Proposals::DestroyAllProposals.call(organization)
    end

    puts "Finish destroy_all_proposals of #{ENV["DECIDIM_ORGANIZATION_NAME"]}"
  end

  desc "Destroy all blogs for a given organization"
  task destroy_all_blogs: :environment do
    puts "Start destroy_all_blogs of #{ENV["DECIDIM_ORGANIZATION_NAME"]}"

    organization = Decidim::Organization.find_by(name: ENV["DECIDIM_ORGANIZATION_NAME"])

    unless organization
      puts "Organization not found: '#{ENV["DECIDIM_ORGANIZATION_NAME"]}'"
      puts "Usage: DECIDIM_ORGANIZATION_NAME=<organization name> rails delete::destroy_all_blogs"
      return
    end

    Decidim::Blogs::Post.transaction do
      Decidim::Blogs::DestroyAllPosts.call(organization)
    end

    puts "Finish destroy_all_blogs of #{ENV["DECIDIM_ORGANIZATION_NAME"]}"
  end

  desc "Destroy all debates for a given organization"
  task destroy_all_debates: :environment do
    puts "Start destroy_all_debates of #{ENV["DECIDIM_ORGANIZATION_NAME"]}"

    organization = Decidim::Organization.find_by(name: ENV["DECIDIM_ORGANIZATION_NAME"])

    unless organization
      puts "Organization not found: '#{ENV["DECIDIM_ORGANIZATION_NAME"]}'"
      puts "Usage: DECIDIM_ORGANIZATION_NAME=<organization name> rails delete::destroy_all_debates"
      return
    end

    Decidim::Debates::Debate.transaction do
      Decidim::Debates::DestroyAllDebates.call(organization)
    end

    puts "Finish destroy_all_debates of #{ENV["DECIDIM_ORGANIZATION_NAME"]}"
  end

  desc "Destroy all meetings for a given organization"
  task destroy_all_meetings: :environment do
    puts "Start destroy_all_meetings of #{ENV["DECIDIM_ORGANIZATION_NAME"]}"

    organization = Decidim::Organization.find_by(name: ENV["DECIDIM_ORGANIZATION_NAME"])

    unless organization
      puts "Organization not found: '#{ENV["DECIDIM_ORGANIZATION_NAME"]}'"
      puts "Usage: DECIDIM_ORGANIZATION_NAME=<organization name> rails delete::destroy_all_meetings"
      return
    end

    Decidim::Meetings::Meeting.transaction do
      Decidim::Meetings::DestroyAllMeetings.call(organization)
    end

    puts "Finish destroy_all_meetings of #{ENV["DECIDIM_ORGANIZATION_NAME"]}"
  end

  desc "Destroy all pages for a given organization"
  task destroy_all_pages: :environment do
    puts "Start destroy_all_pages of #{ENV["DECIDIM_ORGANIZATION_NAME"]}"

    organization = Decidim::Organization.find_by(name: ENV["DECIDIM_ORGANIZATION_NAME"])

    unless organization
      puts "Organization not found: '#{ENV["DECIDIM_ORGANIZATION_NAME"]}'"
      puts "Usage: DECIDIM_ORGANIZATION_NAME=<organization name> rails delete::destroy_all_pages"
      return
    end

    Decidim::Pages::Page.transaction do
      Decidim::Pages::DestroyAllPages.call(organization)
    end

    puts "Finish destroy_all_pages of #{ENV["DECIDIM_ORGANIZATION_NAME"]}"
  end
end
