# frozen_string_literal: true

# Editing a questionnaire answer is implemented upstream as "destroy the
# previous answers and write new ones". The destroy and the reload must agree on
# who the respondent is, but upstream builds that identity as
# (user AND session_token AND ip_hash). ip_hash changes whenever the connection
# does, so when someone edits from a different network the destroy matches
# nothing and the new answers are appended, leaving two answers for the same
# question. The reload uses the same condition, so the edit form can also open
# empty ("my previous answers disappeared").
#
# The identity contract already exists in Decidim::Forms::Questionnaire#answered_by?:
#
#   logged in -> user, anonymous -> session_token
#
# This initializer applies that single definition to both the destroy and the
# reload, and drops ip_hash from the identity. The anonymous case is unchanged
# apart from the ip_hash removal; the logged-in case no longer depends on
# session_token (which is derived from a per-questionnaire salt and could be
# regenerated), so the user is matched even if the salt changes.
module DecidimCfjRespondentIdentity
  # Returns the WHERE conditions that identify a respondent's answers.
  #
  # It raises when the respondent cannot be resolved (neither a user nor a
  # session token) rather than returning a degenerate condition:
  #
  # - { session_token: nil } would translate to "session_token IS NULL", an
  #   implicit and easy-to-widen match for a destructive query.
  # - returning an empty record would silently reopen the edit form empty, which
  #   is the very symptom this override fixes.
  #
  # An unresolvable identity is a programming error (the form requires a session
  # token and the edit path requires a user), so it must fail loudly.
  def self.for_respondent(user, session_token)
    return { user: } if user.present?
    return { session_token: } if session_token.present?

    raise ArgumentError, "cannot resolve the questionnaire respondent: no user and no session token"
  end
end

module DecidimCfjClearAnswersByIdentity
  private

  def clear_answers!
    identity = DecidimCfjRespondentIdentity.for_respondent(current_user, form.context.session_token)
    Decidim::Forms::Answer.where(questionnaire:, **identity).destroy_all
  end
end

module DecidimCfjAddAnswersByIdentity
  # ip_hash is accepted to keep the controller's call signature working, but is
  # no longer part of the respondent identity.
  # rubocop:disable Lint/UnusedMethodArgument
  def add_answers!(questionnaire:, session_token:, ip_hash:)
    identity = DecidimCfjRespondentIdentity.for_respondent(current_user, session_token)

    self.responses = questionnaire.questions.map do |question|
      Decidim::Forms::AnswerForm.from_model(Decidim::Forms::Answer.where(question:, **identity).order(id: :desc).first_or_initialize)
    end
  end
  # rubocop:enable Lint/UnusedMethodArgument
end

Rails.application.config.to_prepare do
  Decidim::Forms::AnswerQuestionnaire # rubocop:disable Lint/Void
  Decidim::Forms::QuestionnaireForm # rubocop:disable Lint/Void

  Decidim::Forms::AnswerQuestionnaire.prepend(DecidimCfjClearAnswersByIdentity) unless Decidim::Forms::AnswerQuestionnaire.include?(DecidimCfjClearAnswersByIdentity)
  Decidim::Forms::QuestionnaireForm.prepend(DecidimCfjAddAnswersByIdentity) unless Decidim::Forms::QuestionnaireForm.include?(DecidimCfjAddAnswersByIdentity)
end
