# frozen_string_literal: true

require "rails_helper"
require "decidim/surveys/test/factories"

RSpec.describe "Decidim::Surveys PublishResponsesController organization scope" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user, :admin, :confirmed, organization:) }
  let(:participatory_process) { create(:participatory_process, organization:) }
  let(:component) { create(:surveys_component, participatory_space: participatory_process) }
  let!(:survey) { create(:survey, component:) }
  let(:own_question) { survey.questionnaire.questions.first }

  let(:other_organization) { create(:organization) }
  let(:other_process) { create(:participatory_process, organization: other_organization) }
  let(:other_component) { create(:surveys_component, participatory_space: other_process) }
  let!(:other_survey) { create(:survey, component: other_component) }
  let(:other_question) { other_survey.questionnaire.questions.first }

  before do
    host! organization.host
    sign_in admin_user, scope: :user
  end

  def publish_response_path(question)
    Decidim::EngineRouter
      .admin_proxy(component)
      .survey_publish_response_path(survey_id: survey.id, id: question.id)
  end

  describe "PATCH update" do
    it "does not publish the answers of a question in another organization" do
      expect { patch publish_response_path(other_question) }
        .not_to change { other_question.reload.survey_responses_published_at }

      expect(response).to have_http_status(:not_found)
    end

    it "publishes the answers of a question in the authorised survey" do
      patch publish_response_path(own_question)

      expect(own_question.reload.survey_responses_published_at).to be_present
    end
  end

  describe "DELETE destroy" do
    before { other_question.update!(survey_responses_published_at: Time.current) }

    it "does not unpublish the answers of a question in another organization" do
      expect { delete publish_response_path(other_question) }
        .not_to change { other_question.reload.survey_responses_published_at }

      expect(response).to have_http_status(:not_found)
    end
  end
end
