# frozen_string_literal: true

require "rails_helper"
require "decidim/forms/test/factories"

# Regression spec for the survey "publish answers" column chart aggregation.
#
# Decidim v0.31's Decidim::Surveys::PublishResponsesHelper#options_column_chart_wrapper
# aggregates with `question.answers.map { ... }.tally`, which counts *combinations*
# of selected options per answer instead of counting each option. For multiple_option
# questions where a single answer selects two or more options, the chart is therefore
# wrong (one bar per unique combination, labels rendered as stringified arrays).
#
# This spec builds a multiple_option question where one answer selects 3 options and
# two answers select 1 option each, then asserts the chart aggregates *per option*.
# It FAILS against the current (buggy) helper and PASSES once the aggregation is fixed
# to `flat_map`.
module Decidim
  module Surveys
    describe PublishResponsesHelper do
      # The :questionnaire_question factory builds a valid questionnaire attached to a
      # participatory space, so we do not need to wire up a survey/component by hand.
      let(:question) do
        create(:questionnaire_question, question_type: "multiple_option", position: 0)
      end
      let(:questionnaire) { question.questionnaire }

      # Three known options so we can assert on exact labels/counts.
      let!(:option_a) { create(:answer_option, question:, body: { "en" => "Option A", "ja" => "選択肢A" }) }
      let!(:option_b) { create(:answer_option, question:, body: { "en" => "Option B", "ja" => "選択肢B" }) }
      let!(:option_c) { create(:answer_option, question:, body: { "en" => "Option C", "ja" => "選択肢C" }) }

      before do
        # Answer 1: selects A, B and C (multiple selection in a single answer)
        answer1 = create(:answer, questionnaire:, question:)
        [option_a, option_b, option_c].each do |opt|
          create(:answer_choice, answer: answer1, answer_option: opt, matrix_row: nil, body: opt.body["en"])
        end

        # Answer 2: selects only A
        answer2 = create(:answer, questionnaire:, question:)
        create(:answer_choice, answer: answer2, answer_option: option_a, matrix_row: nil, body: option_a.body["en"])

        # Answer 3: selects only C
        answer3 = create(:answer, questionnaire:, question:)
        create(:answer_choice, answer: answer3, answer_option: option_c, matrix_row: nil, body: option_c.body["en"])
      end

      describe "#chart_for_question aggregation for multiple_option" do
        subject(:chart_html) { helper.chart_for_question(question.id).to_s }

        it "counts each selected option (A=2, B=1, C=2), not the per-answer combination" do
          # Correct per-option aggregation that Chartkick should receive.
          expect(chart_html).to include('["Option A",2]')
          expect(chart_html).to include('["Option B",1]')
          expect(chart_html).to include('["Option C",2]')

          # And it must NOT emit combination keys (stringified arrays as labels).
          expect(chart_html).not_to include('[["Option A","Option B","Option C"],1]')
        end
      end

      # single_option must keep working after the fix (each answer has exactly one choice).
      describe "#chart_for_question aggregation for single_option" do
        let(:single_question) do
          create(:questionnaire_question, questionnaire:, question_type: "single_option", position: 1)
        end
        let!(:s_opt_x) { create(:answer_option, question: single_question, body: { "en" => "X", "ja" => "X" }) }
        let!(:s_opt_y) { create(:answer_option, question: single_question, body: { "en" => "Y", "ja" => "Y" }) }

        before do
          # 2 answers pick X, 1 answer picks Y
          [s_opt_x, s_opt_x, s_opt_y].each do |opt|
            a = create(:answer, questionnaire:, question: single_question)
            create(:answer_choice, answer: a, answer_option: opt, matrix_row: nil, body: opt.body["en"])
          end
        end

        it "counts each option (X=2, Y=1)" do
          html = helper.chart_for_question(single_question.id).to_s
          expect(html).to include('["X",2]')
          expect(html).to include('["Y",1]')
        end
      end
    end
  end
end
