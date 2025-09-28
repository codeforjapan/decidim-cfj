# frozen_string_literal: true

# This migration comes from decidim_ai_comment_moderation (originally 1)
class CreateDecidimAiCommentModerations < ActiveRecord::Migration[7.0]
  def change
    create_table :decidim_ai_comment_moderations do |t|
      t.string :commentable_type, null: false
      t.integer :commentable_id, null: false
      t.jsonb :analysis_result, default: {}
      t.float :confidence_score
      t.timestamps

      t.index [:commentable_type, :commentable_id], name: "index_ai_comment_moderations_on_commentable"
      t.index :created_at
    end
  end
end