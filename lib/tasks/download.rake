# frozen_string_literal: true

require "csv"
namespace :download do
  desc "Download users list including extended attirubtion"
  task :users, ["org_id"] => :environment do |_task, args|
    file = Rails.root.join("tmp/user_data.csv")
    if args.org_id
      download_users(file, args.org_id)
    else
      puts "*********************"
      puts "[ERROR] please specify org_id"
      puts "example: rake download:users[1]"
      puts "*********************"
      Decidim::Organization.order(:id).each do |org|
        puts "#{org.id}:#{org.name}"
      end
    end
  end

  def format_date(datevalue)
    return nil unless datevalue

    datevalue.strftime("%Y/%m/%d %H:%M:%S")
  end

  def download_users(file, id)
    puts "[INFO] Creating csv files. It will take few minutes"
    headers = %w(id created_at sign_in_count last_sign_in nickname name email real_name gender address birth_year occupation)
    organization = Decidim::Organization.find(id)
    Time.zone = organization.time_zone
    CSV.open(file, "w", write_headers: true, headers: headers, force_quotes: true) do |writer|
      Decidim::User.where(organization: organization).not_deleted.in_batches do |users|
        metadata_hash = {}
        Decidim::Authorization.where(decidim_user_id: users).find_each do |auth|
          metadata_hash[auth.decidim_user_id] = auth.metadata
        end

        users.each do |user|
          metadata = metadata_hash[user.id] || {}

          writer << [user.id, format_date(user.created_at), user.sign_in_count,
                     format_date(user.last_sign_in_at), user.nickname, user.name, user.email,
                     metadata["real_name"], metadata["gender"], metadata["address"],
                     metadata["birth_year"], metadata["occupation"]]
        end
      end
    end
    puts "[INFO] success: #{file} was created."
  end
end
