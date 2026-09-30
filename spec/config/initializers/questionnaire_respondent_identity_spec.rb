# frozen_string_literal: true

require "rails_helper"

# Regression coverage for the respondent identity override: upstream keys the
# destroy/reload of an edited response on (user, session_token, ip_hash), so a
# changed connection duplicates the response and empties the edit form. The
# override keys it on user (logged in) or session_token (anonymous) instead.
RSpec.describe "Questionnaire respondent identity override" do
  include_context "with a questionnaire response form"

  let!(:question) do
    create(
      :questionnaire_question,
      questionnaire:,
      question_type: "short_response",
      mandatory: false,
      position: 0
    )
  end

  let(:responses) { Decidim::Forms::Response.where(questionnaire:) }

  def response_params(body)
    [{ question_id: question.id.to_s, body: }]
  end

  context "when a logged-in user edits" do
    it "replaces the previous response instead of appending a duplicate when the ip changes" do
      expect(submit(build_form(response_params("first"), ip_hash: "ip-1"))).to eq(:ok)

      expect(
        submit(build_form(response_params("second"), ip_hash: "ip-2"), allow_editing_responses: true)
      ).to eq(:ok)

      expect(responses.where(question:).count).to eq(1)
      expect(responses.find_by(question:).body).to eq("second")
    end

    it "replaces the previous response even when the session token changes" do
      expect(submit(build_form(response_params("first"), session_token: "token-1", ip_hash: "ip-1"))).to eq(:ok)

      expect(
        submit(build_form(response_params("second"), session_token: "token-2", ip_hash: "ip-2"), allow_editing_responses: true)
      ).to eq(:ok)

      expect(responses.where(question:).count).to eq(1)
      expect(responses.find_by(question:).body).to eq("second")
    end

    it "reloads the previous response for the edit form despite a different ip and token" do
      expect(submit(build_form(response_params("first"), session_token: "token-1", ip_hash: "ip-1"))).to eq(:ok)

      form = build_form(response_params("second"), session_token: "token-2", ip_hash: "ip-2")
      form.add_responses!(questionnaire:, session_token: "token-2", ip_hash: "ip-2")

      response = form.responses.find { |r| r.question_id.to_i == question.id }
      expect(response.body).to eq("first")
    end

    context "when the respondent already has duplicate responses for a question" do
      let!(:older) { create(:response, questionnaire:, question:, user:, body: "older", session_token: "token-1", ip_hash: "ip-1") }
      let!(:newer) { create(:response, questionnaire:, question:, user:, body: "newer", session_token: "token-1", ip_hash: "ip-2") }

      it "reloads the newest response for the edit form" do
        form = build_form(response_params("ignored"))
        form.add_responses!(questionnaire:, session_token: "session-token-abc", ip_hash: "ip-hash-abc")

        response = form.responses.find { |r| r.question_id.to_i == question.id }
        expect(response.body).to eq("newer")
      end

      it "clears both rows on edit" do
        expect(submit(build_form(response_params("edited")), allow_editing_responses: true)).to eq(:ok)

        expect(responses.where(question:).pluck(:body)).to eq(["edited"])
      end
    end
  end

  context "when an anonymous respondent edits" do
    it "replaces the previous response for the same session token when the ip changes" do
      expect(
        submit(build_form(response_params("first"), current_user: nil, session_token: "anon-1", ip_hash: "ip-1"))
      ).to eq(:ok)

      expect(
        submit(
          build_form(response_params("second"), current_user: nil, session_token: "anon-1", ip_hash: "ip-2"),
          allow_editing_responses: true
        )
      ).to eq(:ok)

      expect(responses.where(question:).count).to eq(1)
      expect(responses.find_by(question:).body).to eq("second")
    end

    it "does not delete another session's responses" do
      expect(
        submit(build_form(response_params("first"), current_user: nil, session_token: "anon-1", ip_hash: "ip-1"))
      ).to eq(:ok)

      expect(
        submit(
          build_form(response_params("second"), current_user: nil, session_token: "anon-2", ip_hash: "ip-1"),
          allow_editing_responses: true
        )
      ).to eq(:ok)

      expect(responses.where(question:).count).to eq(2)
    end
  end

  describe DecidimCfjRespondentIdentity do
    it "keys on the user when logged in" do
      expect(described_class.for_respondent(user, "some-token")).to eq({ user: })
    end

    it "keys on the session token when anonymous" do
      expect(described_class.for_respondent(nil, "some-token")).to eq({ session_token: "some-token" })
    end

    it "raises when neither a user nor a session token is present" do
      expect { described_class.for_respondent(nil, nil) }.to raise_error(ArgumentError)
      expect { described_class.for_respondent(nil, "") }.to raise_error(ArgumentError)
    end
  end
end
