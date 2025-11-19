# frozen_string_literal: true

class CreateDecidimAiCommentModerations < ActiveRecord::Migration[7.0]
  def change
    create_table :decidim_ai_comment_moderation_comment_moderations do |t|
      t.string :commentable_type, null: false
      t.integer :commentable_id, null: false
      t.jsonb :analysis_result, default: {}
      t.float :confidence_score
      t.timestamps

      # Composite index for commentable polymorphic association
      t.index [:commentable_type, :commentable_id], name: "index_ai_comment_moderations_on_commentable"

      # Index for timestamp queries
      t.index :created_at, name: "index_ai_comment_moderations_on_created_at"

      # Indexes for common JSONB queries
      t.index "(analysis_result ->> 'flagged')", name: "index_ai_comment_moderations_on_flagged"
      t.index "(analysis_result ->> 'decidim_reason')", name: "index_ai_comment_moderations_on_decidim_reason"
      t.index "(analysis_result ->> 'severity')", name: "index_ai_comment_moderations_on_severity"

      # GIN index for JSONB containment queries (@> operator)
      t.index :analysis_result, using: :gin, name: "index_ai_comment_moderations_on_analysis_result_gin"

      # Index for confidence score queries
      t.index :confidence_score, name: "index_ai_comment_moderations_on_confidence_score"
    end
  end
end
