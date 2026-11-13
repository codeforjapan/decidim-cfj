# frozen_string_literal: true

# Match the "match" display condition value as plain text instead of as a
# regexp, with the same result on the server and the client sides.
#
# The client side (src/decidim/forms/display_conditions.component.js in
# decidim-forms) builds `new RegExp(value, "i")` from `to_html_data`, so the
# values are escaped there, and the server side folds case in the same way
# as that regexp does.

module DecidimCfjDisplayConditionMatchOverride
  # A pattern that never matches, as the server side does with blank values
  NEVER_MATCH_PATTERN = "(?!)"

  def to_html_data
    data = super
    return data unless condition_type == "match"

    values = condition_value.to_h.values.compact_blank
    pattern = values.any? ? values.map { |value| Regexp.escape(value) }.join("|") : NEVER_MATCH_PATTERN
    data.merge(value: pattern)
  end

  private

  def response_form_matches?(response_form, value)
    search = js_case_fold(value)
    if response_form.body
      js_case_fold(response_form.body).include?(search)
    else
      response_form.choices.any? do |choice_value|
        # The client side checks custom_body if present, otherwise body
        text = choice_value.custom_body.presence || choice_value.body
        text.present? && js_case_fold(text).include?(search)
      end
    end
  end

  # Emulates Canonicalize() of ECMAScript RegExp with the "i" flag and without the "u" flag
  def js_case_fold(str)
    str.each_char.map do |char|
      upcased = char.upcase
      char.ord > 0xFFFF || upcased.length != 1 || (char.ord >= 128 && upcased.ord < 128) ? char : upcased
    end.join
  end
end

Rails.application.config.to_prepare do
  Decidim::Forms::DisplayCondition.prepend(DecidimCfjDisplayConditionMatchOverride)
end
