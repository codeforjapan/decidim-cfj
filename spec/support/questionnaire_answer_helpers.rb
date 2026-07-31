# frozen_string_literal: true

# Shared setup for the questionnaire answer initializer specs. Drives
# Decidim::Forms::AnswerQuestionnaire the way the questionnaire answer action
# does, using ActionController::Parameters so parameter coercion matches a real
# request.
RSpec.shared_context "with a questionnaire answer form" do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :confirmed, organization:) }
  let(:participatory_process) { create(:participatory_process, organization:) }
  let(:questionnaire) { create(:questionnaire, questionnaire_for: participatory_process) }

  # NOTE: in 0.30.x the QuestionnaireForm attribute is `responses` even though
  # the persisted model is Decidim::Forms::Answer.
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
    Decidim::Forms::AnswerQuestionnaire.call(form, questionnaire) do
      on(:ok) { outcome = :ok }
      on(:invalid) { outcome = :invalid }
    end
    outcome
  end
end
