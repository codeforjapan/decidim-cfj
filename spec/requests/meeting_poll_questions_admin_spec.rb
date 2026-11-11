# frozen_string_literal: true

require "rails_helper"
require "decidim/meetings/test/factories"

# Covers config/initializers/meeting_poll_questions_admin_override.rb.
RSpec.describe "Admin variant of meeting poll questions" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization) }
  let(:process) { create(:participatory_process, :published, organization:) }
  let(:component) { create(:meeting_component, :published, participatory_space: process) }
  let(:meeting) { create(:meeting, :published, :online, component:) }
  let(:poll) { create(:poll, meeting:) }
  let(:questionnaire) { create(:meetings_poll_questionnaire, questionnaire_for: poll) }
  let(:unpublished_question_body) { "Question not sent yet" }
  let(:questions_path) { "/processes/#{process.slug}/f/#{component.id}/meetings/#{meeting.id}/polls/questions" }

  before do
    create(:meetings_poll_question, :unpublished, questionnaire:, body: { en: unpublished_question_body })
    host! organization.host
  end

  context "when a visitor asks for the admin variant" do
    before { get questions_path, params: { admin: true }, xhr: true, headers: { "Accept" => "text/javascript" } }

    it "does not render the questions" do
      expect(response).to have_http_status(:redirect)
      expect(response.body).not_to include(unpublished_question_body)
    end
  end

  context "when a user asks for the admin variant" do
    let(:user) { create(:user, :confirmed, organization:) }

    before do
      sign_in user, scope: :user
      get questions_path, params: { admin: true }, xhr: true, headers: { "Accept" => "text/javascript" }
    end

    it "does not render the questions" do
      expect(response).to have_http_status(:redirect)
      expect(response.body).not_to include(unpublished_question_body)
    end
  end

  context "when a user asks for the regular questions" do
    let(:user) { create(:user, :confirmed, organization:) }

    before do
      sign_in user, scope: :user
      get questions_path, xhr: true, headers: { "Accept" => "text/javascript" }
    end

    it "renders the regular questions" do
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("data-decidim-meetings-poll")
      expect(response.body).not_to include("data-decidim-admin-meetings-poll")
      expect(response.body).not_to include(unpublished_question_body)
    end
  end

  context "when an admin asks for the admin variant" do
    let(:admin_user) { create(:user, :admin, :confirmed, organization:) }

    before do
      sign_in admin_user, scope: :user
      get questions_path, params: { admin: true }, xhr: true, headers: { "Accept" => "text/javascript" }
    end

    it "renders the admin questions" do
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("data-decidim-admin-meetings-poll")
      expect(response.body).to include(unpublished_question_body)
    end
  end
end
