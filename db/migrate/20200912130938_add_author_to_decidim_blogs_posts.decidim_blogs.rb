# frozen_string_literal: true
# This migration comes from decidim_blogs (originally 20171211084630)

class AddAuthorToDecidimBlogsPosts < ActiveRecord::Migration[5.1]
  def change
    add_column :decidim_blogs_posts, :decidim_author_id, :integer, index: true
  end
end
