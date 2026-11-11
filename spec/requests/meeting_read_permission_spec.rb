# frozen_string_literal: true

require "rails_helper"
require "decidim/meetings/test/factories"

# Covers config/initializers/meeting_read_permission_override.rb.
RSpec.describe "Meeting read permission" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization) }
  let(:process) { create(:participatory_process, :published, organization:) }
  let(:component) { create(:meeting_component, :published, participatory_space: process) }
  let(:component_path) { "/processes/#{process.slug}/f/#{component.id}" }
  let(:meeting_title) { "Meeting title for the read check" }
  let(:public_meeting) { create(:meeting, :published, :online, component:, title: { en: meeting_title }) }
  let(:private_meeting) { create(:meeting, :published, :online, component:, private_meeting: true, transparent: false, title: { en: meeting_title }) }
  let(:unpublished_meeting) { create(:meeting, :online, component:, title: { en: meeting_title }) }
  let(:registered_user) { create(:user, :confirmed, organization:) }
  let(:admin_user) { create(:user, :admin, :confirmed, organization:) }

  before do
    host! organization.host
  end

  describe "calendar file of a meeting" do
    context "when the meeting is public" do
      before { get "#{component_path}/calendar/meetings/#{public_meeting.id}" }

      it "returns the calendar file" do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(meeting_title)
      end
    end

    context "when the meeting is private" do
      before { get "#{component_path}/calendar/meetings/#{private_meeting.id}" }

      it "does not return the calendar file" do
        expect(response).to have_http_status(:redirect)
      end
    end

    context "when the meeting is private and the user is registered" do
      before do
        create(:registration, meeting: private_meeting, user: registered_user)
        sign_in registered_user, scope: :user
        get "#{component_path}/calendar/meetings/#{private_meeting.id}"
      end

      it "returns the calendar file" do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(meeting_title)
      end
    end

    context "when the meeting is not published" do
      before { get "#{component_path}/calendar/meetings/#{unpublished_meeting.id}" }

      it "does not return the calendar file" do
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe "versions of a meeting", versioning: true do
    context "when the meeting is public" do
      before { get "#{component_path}/meetings/#{public_meeting.id}/versions/1" }

      it "shows the version" do
        expect(response).to have_http_status(:ok)
      end
    end

    context "when the meeting is private" do
      before { get "#{component_path}/meetings/#{private_meeting.id}/versions/1" }

      it "does not show the version" do
        expect(response).to have_http_status(:redirect)
      end
    end

    context "when the meeting is private and an admin opens it" do
      before do
        sign_in admin_user, scope: :user
        get "#{component_path}/meetings/#{private_meeting.id}/versions/1"
      end

      it "shows the version" do
        expect(response).to have_http_status(:ok)
      end
    end

    context "when the meeting is not published" do
      before { get "#{component_path}/meetings/#{unpublished_meeting.id}/versions/1" }

      it "does not show the version" do
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe "poll questions of a meeting" do
    let(:questions_path) { "#{component_path}/meetings/#{meeting.id}/polls/questions" }
    let(:poll) { create(:poll, meeting:) }
    let(:questionnaire) { create(:meetings_poll_questionnaire, questionnaire_for: poll) }
    let(:unpublished_question_body) { "Question not sent yet" }

    before do
      create(:meetings_poll_question, :unpublished, questionnaire:, body: { en: unpublished_question_body })
    end

    context "when the meeting is public" do
      let(:meeting) { public_meeting }

      before { get questions_path, xhr: true, headers: { "Accept" => "text/javascript" } }

      it "renders the questions" do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("data-decidim-meetings-poll")
        expect(response.body).not_to include(unpublished_question_body)
      end
    end

    context "when the meeting is private" do
      let(:meeting) { private_meeting }

      before { get questions_path, xhr: true, headers: { "Accept" => "text/javascript" } }

      it "does not render the questions" do
        expect(response).to have_http_status(:redirect)
      end
    end

    context "when the meeting is private and the user is registered" do
      let(:meeting) { private_meeting }

      before do
        create(:registration, meeting:, user: registered_user)
        sign_in registered_user, scope: :user
        get questions_path, xhr: true, headers: { "Accept" => "text/javascript" }
      end

      it "renders the questions" do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("data-decidim-meetings-poll")
      end
    end
  end
end
