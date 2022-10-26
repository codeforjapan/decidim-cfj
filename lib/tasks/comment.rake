# frozen_string_literal: true

namespace :comment do
  desc "Remove all orphan comments"
  task remove_orphans: :environment do
    puts "Start remove_orphans"
    Decidim::Comments::Comment.find_each do |comment|
      unless comment.root_commentable && comment.commentable
        puts "Remove comment #{comment.id}"
        comment.delete!
      end
    end
    puts "Finish remove_orphans"
  end
end
