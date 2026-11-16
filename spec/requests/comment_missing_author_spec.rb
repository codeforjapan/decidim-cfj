# frozen_string_literal: true

require "rails_helper"
require "decidim/meetings/test/factories"

# Covers config/initializers/comment_cell_missing_author_override.rb.
RSpec.describe "Comment whose author no longer exists" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization) }
  let(:process) { create(:participatory_process, :published, organization:) }
  let(:component) { create(:meeting_component, :published, participatory_space: process) }
  let(:meeting) { create(:meeting, :published, :online, component:) }
  let(:comment) { create(:comment, commentable: meeting, body: { en: "Comment by a removed author" }) }
  let(:meeting_path) { "/#{organization.default_locale}/processes/#{process.slug}/f/#{component.id}/meetings/#{meeting.id}" }

  before do
    host! organization.host
    Decidim::UserBaseEntity.where(id: comment.decidim_author_id).delete_all
  end

  context "when the visitor is not signed in" do
    it "renders the comment without the author actions" do
      get meeting_path, params: { commentId: comment.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Comment by a removed author")
      expect(response.body).not_to include("editCommentModal#{comment.id}")
    end
  end

  # Caching is disabled in the test environment, but production builds the
  # cache key of the comment for visitors who are not signed in.
  context "when the visitor is not signed in and caching is enabled" do
    before { allow(ActionController::Base).to receive(:perform_caching).and_return(true) }

    it "renders the comment" do
      get meeting_path, params: { commentId: comment.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Comment by a removed author")
    end
  end

  context "when the visitor is signed in" do
    before { sign_in create(:user, :confirmed, organization:) }

    it "renders the comment without the author actions" do
      get meeting_path, params: { commentId: comment.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Comment by a removed author")
      expect(response.body).not_to include("editCommentModal#{comment.id}")
    end
  end
end
