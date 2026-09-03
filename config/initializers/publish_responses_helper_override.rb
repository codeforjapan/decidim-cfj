# frozen_string_literal: true

# Override Decidim::Surveys::PublishResponsesHelper#options_column_chart_wrapper.
#
# Decidim v0.31's implementation aggregates the published survey column chart with
#
#   question.answers.map { |answer| answer.choices.map { ... } }.tally
#
# `.map` produces one array of option labels *per answer*, so `.tally` counts unique
# combinations of options instead of counting each option. For multiple_option
# questions this renders one bar per answer-combination and labels the x-axis with the
# stringified array (e.g. `["A","B","C"]`). Single_option questions happen to look
# correct only because every answer has exactly one choice.
#
# Replacing `.map` with `.flat_map` flattens the per-answer arrays into a single list
# of option labels, so `.tally` counts each selected option. See the verification
# report in docs/decidim-survey-chart-verification.md.
Rails.application.config.to_prepare do
  Decidim::Surveys::PublishResponsesHelper.module_eval do
    def options_column_chart_wrapper(question)
      tally = question.answers.flat_map { |answer| answer.choices.map { |choice| translated_attribute(choice.answer_option.body) } }.tally

      column_chart(tally, download: true)
    end
  end
end
