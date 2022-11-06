# frozen_string_literal: true

class CommentForMigration < ActiveRecord::Base # rubocop:disable Rails/ApplicationRecord
  self.table_name = :decidim_comments_comments
end

namespace :comment do
  desc "Remove all orphan comments"
  task remove_orphans: :environment do
    puts "Start remove_orphans"

    CommentForMigration.transaction do
      CommentForMigration.find_each do |comment|
        commentable_id = comment.decidim_commentable_id
        commentable_type = comment.decidim_commentable_type

        begin
          commentable_class = commentable_type.constantize
          comment_obj = commentable_class.find(commentable_id)
          puts "OK: #{comment.id}, #{comment_obj.class}(id: #{comment_obj.id})"
        rescue ActiveRecord::RecordNotFound, NameError
          puts "XXX Remove comment #{comment.id}"
          comment.destroy!
        end
      end
    end

    puts "Finish remove_orphans"
  end
end
