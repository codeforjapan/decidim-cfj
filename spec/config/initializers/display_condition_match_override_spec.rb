# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Decidim::Forms::DisplayCondition match override" do
  subject(:display_condition) do
    build(
      :display_condition,
      :match,
      question:,
      condition_question:,
      condition_value:
    )
  end

  let(:questionnaire) { create(:questionnaire) }
  let(:condition_question) { create(:questionnaire_question, questionnaire:, position: 2) }
  let(:question) { create(:questionnaire_question, questionnaire:, position: 3) }
  let(:condition_value) { { en: "To be" } }

  describe "#fulfilled?" do
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
      let(:condition_value) { { en: "a|b" } }
      let(:answer_body) { "a" }

      it "treats it as plain text" do
        expect(display_condition.fulfilled?(answer_form)).to be false
      end
    end

    context "when the value is an invalid regexp" do
      let(:condition_value) { { en: "c++ (" } }
      let(:answer_body) { "I use C++ (and Ruby)" }

      it "matches it as plain text" do
        expect(display_condition.fulfilled?(answer_form)).to be true
      end
    end

    context "when the value of another locale matches" do
      let(:condition_value) { { en: "yes", ja: "はい" } }
      let(:answer_body) { "はい、そうです" }

      it "matches it" do
        expect(display_condition.fulfilled?(answer_form)).to be true
      end
    end

    context "when the values are blank" do
      let(:condition_value) { { en: "" } }

      it "does not match" do
        expect(display_condition.fulfilled?(answer_form)).to be false
      end
    end

    context "when the answer has only choices" do
      let(:answer_body) { nil }
      let(:choice_attributes) { { answer_option_id: 1, body: "Option", custom_body: "My To Be answer" } }

      it "matches the custom body" do
        expect(display_condition.fulfilled?(answer_form)).to be true
      end
    end

    context "when the body of the choice matches but the custom body does not" do
      let(:answer_body) { nil }
      let(:choice_attributes) { { answer_option_id: 1, body: "To be", custom_body: "Something else" } }

      it "does not match, as the client side does" do
        expect(display_condition.fulfilled?(answer_form)).to be false
      end
    end

    context "when the choice has no custom body" do
      let(:answer_body) { nil }
      let(:choice_attributes) { { answer_option_id: 1, body: "To be", custom_body: "" } }

      it "matches the body" do
        expect(display_condition.fulfilled?(answer_form)).to be true
      end
    end

    context "when the answer has a letter folded differently by ECMAScript RegExp" do
      let(:condition_value) { { en: "k" } }
      let(:answer_body) { "K" } # KELVIN SIGN

      it "does not match, as the client side does" do
        expect(display_condition.fulfilled?(answer_form)).to be false
      end
    end

    context "when the answer has a letter folded only by ECMAScript RegExp" do
      let(:condition_value) { { en: "ς" } }
      let(:answer_body) { "Σ" }

      it "matches, as the client side does" do
        expect(display_condition.fulfilled?(answer_form)).to be true
      end
    end
  end

  describe "#to_html_data" do
    let(:condition_value) { { en: "a|b", ja: "c++ (", es: "" } }

    it "passes the escaped values of all locales" do
      expect(display_condition.to_html_data[:value]).to eq("a\\|b|c\\+\\+\\ \\(")
    end

    context "when the values are blank" do
      let(:condition_value) { { en: "" } }

      it "passes a pattern that never matches" do
        expect(display_condition.to_html_data[:value]).to eq("(?!)")
      end
    end

    context "when the condition type is not match" do
      subject(:display_condition) { build(:display_condition, question:, condition_question:) }

      it "does not pass the value" do
        expect(display_condition.to_html_data).not_to have_key(:value)
      end
    end
  end
end
