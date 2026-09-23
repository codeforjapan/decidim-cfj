# frozen_string_literal: true

require "rails_helper"

# Regression coverage for the respondent identity override: upstream keys the
# destroy/reload of an edited answer on (user, session_token, ip_hash), so a
# changed connection duplicates the answer and empties the edit form. The
# override keys it on user (logged in) or session_token (anonymous) instead.
RSpec.describe "Questionnaire respondent identity override" do
  include_context "with a questionnaire answer form"

  let!(:question) do
    create(
      :questionnaire_question,
      questionnaire:,
      question_type: "short_answer",
      mandatory: false,
      position: 0
    )
  end

  let(:answers) { Decidim::Forms::Answer.where(questionnaire:) }

  def answer_params(body)
    [{ question_id: question.id.to_s, body: }]
  end

  context "when a logged-in user edits" do
    it "replaces the previous answer instead of appending a duplicate when the ip changes" do
      expect(submit(build_form(answer_params("first"), ip_hash: "ip-1"))).to eq(:ok)

      expect(
        submit(build_form(answer_params("second"), ip_hash: "ip-2"), allow_editing_answers: true)
      ).to eq(:ok)

      expect(answers.where(question:).count).to eq(1)
      expect(answers.find_by(question:).body).to eq("second")
    end

    it "replaces the previous answer even when the session token changes" do
      expect(submit(build_form(answer_params("first"), session_token: "token-1", ip_hash: "ip-1"))).to eq(:ok)

      expect(
        submit(build_form(answer_params("second"), session_token: "token-2", ip_hash: "ip-2"), allow_editing_answers: true)
      ).to eq(:ok)

      expect(answers.where(question:).count).to eq(1)
      expect(answers.find_by(question:).body).to eq("second")
    end

    it "reloads the previous answer for the edit form despite a different ip and token" do
      expect(submit(build_form(answer_params("first"), session_token: "token-1", ip_hash: "ip-1"))).to eq(:ok)

      form = build_form(answer_params("second"), session_token: "token-2", ip_hash: "ip-2")
      form.add_answers!(questionnaire:, session_token: "token-2", ip_hash: "ip-2")

      response = form.responses.find { |r| r.question_id.to_i == question.id }
      expect(response.body).to eq("first")
    end
  end

  context "when an anonymous respondent edits" do
    it "replaces the previous answer for the same session token when the ip changes" do
      expect(
        submit(build_form(answer_params("first"), current_user: nil, session_token: "anon-1", ip_hash: "ip-1"))
      ).to eq(:ok)

      expect(
        submit(
          build_form(answer_params("second"), current_user: nil, session_token: "anon-1", ip_hash: "ip-2"),
          allow_editing_answers: true
        )
      ).to eq(:ok)

      expect(answers.where(question:).count).to eq(1)
      expect(answers.find_by(question:).body).to eq("second")
    end

    it "does not delete another session's answers" do
      expect(
        submit(build_form(answer_params("first"), current_user: nil, session_token: "anon-1", ip_hash: "ip-1"))
      ).to eq(:ok)

      expect(
        submit(
          build_form(answer_params("second"), current_user: nil, session_token: "anon-2", ip_hash: "ip-1"),
          allow_editing_answers: true
        )
      ).to eq(:ok)

      expect(answers.where(question:).count).to eq(2)
    end
  end
end
