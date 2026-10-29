# frozen_string_literal: true

require "rails_helper"
require "decidim/surveys/test/factories"
require "decidim/budgets/test/factories"
require "decidim/meetings/test/factories"
require "decidim/forms/test/factories"

# Covers config/initializers/exports_controller_override.rb.
RSpec.describe "Admin component exports with a resource_id" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user, :admin, :confirmed, organization:, password_updated_at: Time.current) }
  let(:process) { create(:participatory_process, organization:) }
  let(:other_organization) { create(:organization) }
  let(:other_process) { create(:participatory_process, organization: other_organization) }
  let(:exports_path) { "/admin/participatory_processes/#{process.slug}/components/#{component.id}/exports" }
  let(:export_request) { post exports_path, params: { id: export_name, format: "CSV", resource_id: } }

  before do
    host! organization.host
    sign_in admin_user, scope: :user
  end

  describe "survey answers" do
    let(:component) { create(:surveys_component, participatory_space: process) }
    let(:export_name) { "survey_user_answers" }
    let(:own_survey) { create(:survey, component:) }
    let(:other_survey) { create(:survey, component: create(:surveys_component, participatory_space: other_process)) }

    context "when the survey belongs to the component" do
      let(:resource_id) { own_survey.id }

      it "exports the survey" do
        expect { export_request }.to have_enqueued_job(Decidim::ExportJob)
          .with(admin_user, component, export_name, "CSV", own_survey.id, anything)
      end
    end

    context "when the survey belongs to another organization" do
      let(:resource_id) { other_survey.id }

      it "does not export" do
        expect { export_request }.to raise_error(ActiveRecord::RecordNotFound)
        expect(Decidim::ExportJob).not_to have_been_enqueued
      end
    end
  end

  describe "budget projects" do
    let(:component) { create(:budgets_component, participatory_space: process) }
    let(:export_name) { "projects" }
    let(:own_budget) { create(:budget, component:) }
    let(:other_budget) { create(:budget, component: create(:budgets_component, participatory_space: other_process)) }

    context "when the budget belongs to the component" do
      let(:resource_id) { own_budget.id }

      it "exports the budget" do
        expect { export_request }.to have_enqueued_job(Decidim::ExportJob)
          .with(admin_user, component, export_name, "CSV", own_budget.id, anything)
      end
    end

    context "when the budget belongs to another organization" do
      let(:resource_id) { other_budget.id }

      it "does not export" do
        expect { export_request }.to raise_error(ActiveRecord::RecordNotFound)
        expect(Decidim::ExportJob).not_to have_been_enqueued
      end
    end

    context "when the budget belongs to another component of the same organization" do
      let(:resource_id) { create(:budget, component: create(:budgets_component, participatory_space: process)).id }

      it "does not export" do
        expect { export_request }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "meeting poll answers" do
    let(:component) { create(:meeting_component, participatory_space: process) }
    let(:export_name) { "answers" }
    let(:own_questionnaire) { create(:meetings_poll_questionnaire, questionnaire_for: create(:poll, meeting: create(:meeting, component:))) }
    let(:other_meeting) { create(:meeting, component: create(:meeting_component, participatory_space: other_process)) }
    let(:other_questionnaire) { create(:meetings_poll_questionnaire, questionnaire_for: create(:poll, meeting: other_meeting)) }

    context "when the poll belongs to the component" do
      let(:resource_id) { own_questionnaire.id }

      it "exports the poll answers" do
        expect { export_request }.to have_enqueued_job(Decidim::ExportJob)
          .with(admin_user, component, export_name, "CSV", own_questionnaire.id, anything)
      end
    end

    context "when the poll belongs to another organization" do
      let(:resource_id) { other_questionnaire.id }

      it "does not export" do
        expect { export_request }.to raise_error(ActiveRecord::RecordNotFound)
        expect(Decidim::ExportJob).not_to have_been_enqueued
      end
    end
  end

  describe "a user who cannot export" do
    let(:admin_user) { create(:process_collaborator, :confirmed, participatory_process: process, password_updated_at: Time.current) }
    let(:component) { create(:surveys_component, participatory_space: process) }
    let(:export_name) { "survey_user_answers" }
    let(:resource_id) { create(:survey, component: create(:surveys_component, participatory_space: other_process)).id }

    it "is rejected before the resource is looked up" do
      expect { export_request }.not_to raise_error
      expect(response).to have_http_status(:redirect)
      expect(Decidim::ExportJob).not_to have_been_enqueued
    end
  end

  describe "a non-scalar resource_id" do
    let(:component) { create(:surveys_component, participatory_space: process) }
    let(:export_name) { "survey_user_answers" }
    let(:resource_id) { [create(:survey, component:).id] }

    it "does not export" do
      expect { export_request }.to raise_error(ActiveRecord::RecordNotFound)
      expect(Decidim::ExportJob).not_to have_been_enqueued
    end
  end

  describe "an export that does not read a resource_id" do
    let(:component) { create(:meeting_component, participatory_space: process) }
    let(:export_name) { "meetings" }
    let(:resource_id) { other_survey_id }
    let(:other_survey_id) { create(:survey, component: create(:surveys_component, participatory_space: other_process)).id }

    it "exports without the resource_id" do
      expect { export_request }.to have_enqueued_job(Decidim::ExportJob)
        .with(admin_user, component, export_name, "CSV", nil, anything)
    end
  end
end
