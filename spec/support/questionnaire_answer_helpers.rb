# frozen_string_literal: true

# Shared setup for the questionnaire response initializer specs. Drives
# Decidim::Forms::ResponseQuestionnaire the way the questionnaire response action
# does, using ActionController::Parameters so parameter coercion matches a real
# request.
RSpec.shared_context "with a questionnaire response form" do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :confirmed, organization:) }
  let(:participatory_process) { create(:participatory_process, organization:) }
  let(:questionnaire) { create(:questionnaire, questionnaire_for: participatory_process) }

  # The QuestionnaireForm attribute is `responses`, as is the persisted model.
  def build_form(responses)
    params = ActionController::Parameters.new(
      questionnaire: { tos_agreement: "1", responses: }
    )

    Decidim::Forms::QuestionnaireForm.from_params(params).with_context(
      current_organization: organization,
      current_user: user,
      session_token: "session-token-abc",
      ip_hash: "ip-hash-abc"
    )
  end

  def submit(form)
    outcome = nil
    Decidim::Forms::ResponseQuestionnaire.call(form, questionnaire) do
      on(:ok) { outcome = :ok }
      on(:invalid) { outcome = :invalid }
    end
    outcome
  end
end
