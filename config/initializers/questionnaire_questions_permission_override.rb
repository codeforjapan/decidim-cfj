# frozen_string_literal: true

# Backport of decidim/decidim#16665 for the questionnaire question editing
# actions of Decidim::Forms::Admin::Concerns::HasQuestionnaire.
#
# Fixed upstream in 0.31 (#16682) and 0.32 (#16681). release/0.30-stable stopped
# taking backports before it landed, so it has to live here.
#
# In this bundle the two actions are already behind the
# `enforce_permission_to :manage, :component` before_action that
# Decidim::Admin::Components::BaseController runs on everything except :index
# and :show, so this changes no outcome today. It is here so the actions do not
# depend on that single outer check, which controllers can waive through
# `skip_manage_component_permission`.
#
# decidim-templates and decidim-demographics include the concern upstream and
# are not part of this bundle; add them here if that changes.
#
# Removal: delete this file once Decidim is 0.31 or newer. No boot guard: after
# the upgrade the check simply runs twice with the same outcome.

module DecidimCfjQuestionnaireQuestionsPermissionPatch
  def edit_questions
    enforce_permission_to(:update, :questionnaire, questionnaire:)

    super
  end

  def update_questions
    enforce_permission_to(:update, :questionnaire, questionnaire:)

    super
  end
end

Rails.application.config.to_prepare do
  [
    Decidim::Surveys::Admin::SurveysController,
    Decidim::Meetings::Admin::RegistrationFormController
  ].each do |controller|
    controller.prepend(DecidimCfjQuestionnaireQuestionsPermissionPatch)
  end
end
