# frozen_string_literal: true

require "rails_helper"
require "decidim/surveys/test/factories"

# Decidim does not order the surveys of a surveys component, neither in the
# admin index nor in the public list. The order is stored in the
# decidim_cfj_survey_orders side table, see
# config/initializers/surveys_ordering_override.rb.
RSpec.describe "Surveys display order" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user, :admin, :confirmed, organization:) }
  let(:participatory_process) { create(:participatory_process, organization:) }
  let(:component) { create(:surveys_component, participatory_space: participatory_process) }
  let!(:first_survey) { create(:survey, :published, :allow_responses, component:) }
  let!(:second_survey) { create(:survey, :published, :allow_responses, component:) }
  let!(:third_survey) { create(:survey, :published, :allow_responses, component:) }

  let(:reorder_path) { Decidim::EngineRouter.admin_proxy(component).reorder_surveys_path }

  before { host! organization.host }

  def weights
    Decidim::Cfj::SurveyOrder.pluck(:decidim_surveys_survey_id, :weight).to_h
  end

  def listed_survey_ids
    get Decidim::EngineRouter.main_proxy(component).root_path

    [first_survey, second_survey, third_survey].filter_map do |survey|
      path = Decidim::EngineRouter.main_proxy(component).survey_path(survey)
      position = response.body.index(%(#{path}"))
      [survey.id, position] if position
    end.sort_by(&:last).map(&:first)
  end

  def admin_survey_ids(page = nil)
    get Decidim::EngineRouter.admin_proxy(component).surveys_path(page:)

    response.body.scan(/data-record-id="(\d+)"/).flatten.map(&:to_i)
  end

  describe "PUT reorder" do
    before { sign_in admin_user, scope: :user }

    it "stores the weights following the given order" do
      put reorder_path, params: { order_ids: [third_survey.id, first_survey.id, second_survey.id] }

      expect(response).to have_http_status(:ok)
      expect(weights).to eq(third_survey.id => 1, first_survey.id => 2, second_survey.id => 3)
    end

    it "updates the weights of an already ordered component" do
      put reorder_path, params: { order_ids: [first_survey.id, second_survey.id, third_survey.id] }
      put reorder_path, params: { order_ids: [second_survey.id, third_survey.id, first_survey.id] }

      expect(weights).to eq(second_survey.id => 1, third_survey.id => 2, first_survey.id => 3)
    end

    it "keeps the surveys that were not reordered at their position" do
      # The sortable list only sends the ids of the page being reordered.
      put reorder_path, params: { order_ids: [third_survey.id, second_survey.id] }

      expect(weights).to eq(first_survey.id => 1, third_survey.id => 2, second_survey.id => 3)
      expect(listed_survey_ids).to eq([first_survey.id, third_survey.id, second_survey.id])
    end

    it "swaps surveys that do not sit next to each other" do
      fourth_survey = create(:survey, :published, :allow_responses, component:, questionnaire: build(:questionnaire))

      put reorder_path, params: { order_ids: [fourth_survey.id, first_survey.id] }

      expect(weights).to eq(
        fourth_survey.id => 1,
        second_survey.id => 2,
        third_survey.id => 3,
        first_survey.id => 4
      )
    end

    it "ignores surveys of another component" do
      other_component = create(:surveys_component, participatory_space: participatory_process)
      other_survey = create(:survey, component: other_component)

      put reorder_path, params: { order_ids: [other_survey.id, first_survey.id] }

      expect(weights).to eq(first_survey.id => 1, second_survey.id => 2, third_survey.id => 3)
      expect(Decidim::Cfj::SurveyOrder.exists?(decidim_surveys_survey_id: other_survey.id)).to be(false)
    end

    it "does nothing without an order" do
      put reorder_path

      expect(response).to have_http_status(:bad_request)
      expect(weights).to be_empty
    end

    it "does nothing with an unusable order" do
      put reorder_path, params: { order_ids: "nope" }

      expect(response).to have_http_status(:bad_request)
      expect(weights).to be_empty
    end

    it "does nothing when none of the given ids is usable" do
      put reorder_path, params: { order_ids: ["nope", ""] }

      expect(response).to have_http_status(:bad_request)
      expect(weights).to be_empty
    end

    it "drops the ids that are not numbers and the repeated ones" do
      put reorder_path, params: { order_ids: [third_survey.id, "nope", third_survey.id, first_survey.id] }

      expect(response).to have_http_status(:ok)
      expect(weights).to eq(third_survey.id => 1, second_survey.id => 2, first_survey.id => 3)
    end

    context "when the surveys do not fit in a single page" do
      # 3 + 24 surveys, so that the second page of the admin index holds 2 of them.
      let!(:extra_surveys) do
        Array.new(24) { create(:survey, :published, :allow_responses, component:, questionnaire: build(:questionnaire)) }
      end

      it "does not change the previous page when the last one is reordered" do
        first_page = admin_survey_ids
        second_page = admin_survey_ids(2)

        expect(first_page.size).to eq(25)
        expect(second_page.size).to eq(2)

        put reorder_path, params: { order_ids: second_page.reverse }

        expect(admin_survey_ids).to eq(first_page)
        expect(admin_survey_ids(2)).to eq(second_page.reverse)
      end
    end
  end

  describe "GET the admin index" do
    before { sign_in admin_user, scope: :user }

    it "renders a sortable table pointing at the reorder action" do
      get Decidim::EngineRouter.admin_proxy(component).surveys_path

      expect(response.body).to include("data-draggable-table")
      expect(response.body).to include(%(data-sort-url="#{reorder_path}"))
    end

    it "lists the surveys following the configured order" do
      Decidim::Cfj::SurveyOrder.create!(decidim_surveys_survey_id: second_survey.id, weight: 1)

      expect(admin_survey_ids).to eq([second_survey.id, first_survey.id, third_survey.id])
    end
  end

  describe "PUT reorder without admin rights" do
    let(:user) { create(:user, :confirmed, organization:) }
    let(:order_ids) { [third_survey.id, second_survey.id, first_survey.id] }

    before { sign_in user, scope: :user }

    it "does not reach the admin engine as a participant" do
      # The whole admin engine is behind Decidim::Admin::OrganizationDashboardConstraint,
      # so a participant does not even get a route. Since config.action_dispatch
      # .show_exceptions is :rescuable (the Rails 7.2 default), the routing error is
      # rendered as a 404 instead of being raised out of the request.
      put reorder_path, params: { order_ids: }

      expect(response).to have_http_status(:not_found)
      expect(weights).to be_empty
    end

    context "when the user is a collaborator of the space" do
      before do
        create(:participatory_process_user_role, user:, participatory_process:, role: :collaborator)
      end

      it "does not change the order" do
        put reorder_path, params: { order_ids: }

        expect(response).not_to have_http_status(:ok)
        expect(weights).to be_empty
      end
    end
  end

  describe "destroying a survey" do
    it "takes its stored weight with it" do
      Decidim::Cfj::SurveyOrder.create!(decidim_surveys_survey_id: first_survey.id, weight: 1)
      Decidim::Cfj::SurveyOrder.create!(decidim_surveys_survey_id: second_survey.id, weight: 2)

      first_survey.destroy!

      expect(weights).to eq(second_survey.id => 2)
    end
  end

  describe "public index" do
    it "lists the surveys following the configured order" do
      Decidim::Cfj::SurveyOrder.create!(decidim_surveys_survey_id: third_survey.id, weight: 1)
      Decidim::Cfj::SurveyOrder.create!(decidim_surveys_survey_id: first_survey.id, weight: 2)
      Decidim::Cfj::SurveyOrder.create!(decidim_surveys_survey_id: second_survey.id, weight: 3)

      expect(listed_survey_ids).to eq([third_survey.id, first_survey.id, second_survey.id])
    end

    it "lists the surveys without a configured order last, by id" do
      Decidim::Cfj::SurveyOrder.create!(decidim_surveys_survey_id: third_survey.id, weight: 1)

      expect(listed_survey_ids).to eq([third_survey.id, first_survey.id, second_survey.id])
    end

    it "falls back to the id order when nothing is configured" do
      expect(listed_survey_ids).to eq([first_survey.id, second_survey.id, third_survey.id])
    end
  end
end
