# frozen_string_literal: true

# The update/destroy actions authorise against the survey resolved from
# :survey_id, but pass :id straight to the command, which resolves the question
# without a scope. This ties :id to the questionnaire of the authorised survey.
Rails.application.config.to_prepare do
  Decidim::Surveys::Admin::PublishAnswersController # rubocop:disable Lint/Void

  module DecidimSurveysPublishAnswersScopePatch
    def self.prepended(base)
      base.before_action :ensure_question_in_authorised_survey, only: [:update, :destroy]
    end

    private

    def ensure_question_in_authorised_survey
      return if questionnaire.present? &&
                Decidim::Forms::Question.where(questionnaire:).exists?(id: params[:id])

      raise ActionController::RoutingError, "Not Found"
    end
  end

  Decidim::Surveys::Admin::PublishAnswersController.prepend(DecidimSurveysPublishAnswersScopePatch)
end
