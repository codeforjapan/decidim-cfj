# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Decidim::Forms::DisplayCondition match override" do
  subject(:display_condition) do
    build(
      :display_condition,
      :match,
      question:,
      condition_question:,
      condition_value: { en: condition_value }
    )
  end

  let(:questionnaire) { create(:questionnaire) }
  let(:condition_question) { create(:questionnaire_question, questionnaire:, position: 2) }
  let(:question) { create(:questionnaire_question, questionnaire:, position: 3) }
  let(:condition_value) { "To be" }
  let(:answer_body) { "to BE or not to be" }
  let(:choice_attributes) { { answer_option_id: 314_159_265_359 } }
  let(:answer_form) do
    Decidim::Forms::AnswerForm.from_params(
      body: answer_body,
      choices: [Decidim::Forms::AnswerChoiceForm.from_params(choice_attributes)]
    )
  end

  it "matches the value case-insensitively" do
    expect(display_condition.fulfilled?(answer_form)).to be true
  end

  it "does not use a regexp" do
    allow(Regexp).to receive(:new).and_call_original

    display_condition.fulfilled?(answer_form)

    expect(Regexp).not_to have_received(:new)
  end

  context "when the value contains regexp syntax" do
    let(:condition_value) { "a|b" }
    let(:answer_body) { "a" }

    it "treats it as plain text" do
      expect(display_condition.fulfilled?(answer_form)).to be false
    end
  end

  context "when the value is an invalid regexp" do
    let(:condition_value) { "c++ (" }
    let(:answer_body) { "I use C++ (and Ruby)" }

    it "matches it as plain text" do
      expect(display_condition.fulfilled?(answer_form)).to be true
    end
  end

  context "when the answer has only choices" do
    let(:answer_body) { nil }
    let(:choice_attributes) { { answer_option_id: 1, body: "Option", custom_body: "My To Be answer" } }

    it "matches the custom body" do
      expect(display_condition.fulfilled?(answer_form)).to be true
    end
  end
end
