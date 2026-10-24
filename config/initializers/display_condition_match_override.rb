# frozen_string_literal: true

# Match the "match" display condition value as plain text (case-insensitive)
# instead of as a regexp. The client side counterpart is
# src/decidim/forms/display_conditions.component.js.

module DecidimCfjDisplayConditionMatchOverride
  private

  def answer_form_matches?(answer_form, value)
    search = value.downcase
    if answer_form.body
      answer_form.body.downcase.include?(search)
    else
      answer_form.choices.any? do |choice_value|
        choice_value.body&.downcase&.include?(search) || choice_value.custom_body&.downcase&.include?(search)
      end
    end
  end
end

Rails.application.config.to_prepare do
  Decidim::Forms::DisplayCondition.prepend(DecidimCfjDisplayConditionMatchOverride)
end
