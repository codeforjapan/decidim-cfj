# frozen_string_literal: true

require "rails_helper"
require "decidim/surveys/test/factories"

# Mirrors the components reorder spec of decidim-participatory_processes, since
# the surveys admin index reuses the same draggable table.
describe "Admin reorders the surveys of a component" do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, :confirmed, organization:) }
  let(:participatory_process) { create(:participatory_process, organization:) }
  let(:component) { create(:surveys_component, participatory_space: participatory_process) }

  let!(:survey1) { create(:survey, component:, questionnaire: build(:questionnaire, title: { en: "Survey 1", ja: "Survey 1" })) }
  let!(:survey2) { create(:survey, component:, questionnaire: build(:questionnaire, title: { en: "Survey 2", ja: "Survey 2" })) }
  let!(:survey3) { create(:survey, component:, questionnaire: build(:questionnaire, title: { en: "Survey 3", ja: "Survey 3" })) }

  before do
    switch_to_host(organization.host)
    login_as user, scope: :user
    visit Decidim::EngineRouter.admin_proxy(component).surveys_path
  end

  it "changes the order of the surveys" do
    expect(page.text.index("Survey 1")).to be < page.text.index("Survey 2")
    expect(page.text.index("Survey 2")).to be < page.text.index("Survey 3")

    first("td.dragging-handle").drag_to(find("tbody.draggable-table tr:last-child"))

    # The drop rearranges the rows right away and sends the new order in the
    # background, so both have to be waited for before reloading the page.
    # Where exactly the dragged row lands is up to the sortable library, so only
    # the fact that the first survey is no longer the first one is asserted.
    expect(page).to have_css("tbody.draggable-table tr:first-child", text: "Survey 2")
    wait_for_stored_order

    visit current_path

    expect(page.text.index("Survey 2")).to be < page.text.index("Survey 1")

    expect(weights[survey2.id]).to be < weights[survey1.id]
  end

  def weights
    Decidim::Cfj::SurveyOrder.pluck(:decidim_surveys_survey_id, :weight).to_h
  end

  def wait_for_stored_order
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.05 until weights.keys.sort == [survey1.id, survey2.id, survey3.id].sort
    end
  end
end
