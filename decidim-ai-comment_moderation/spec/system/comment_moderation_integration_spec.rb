# frozen_string_literal: true

require "rails_helper"
require "openai"
require_relative "../fixtures/openai_responses"

RSpec.describe "Comment Moderation Integration" do
  include OpenaiResponses

  let(:organization) { create(:organization) }
  let(:participatory_process) { create(:participatory_process, organization:) }
  let(:component) { create(:component, participatory_space: participatory_process, manifest_name: "dummy") }
  let(:commentable) { create(:dummy_resource, component:) }
  let(:author) { create(:user, organization:) }
  let(:comment) { create(:comment, commentable:, author:) }
  let(:openai_client) { instance_double(OpenAI::Client) }

  before do
    Decidim::Ai::CommentModeration.configure do |config|
      config.openai_api_key = "test-key-123"
      config.enabled_hosts = [organization.host]
      config.confidence_threshold = 0.8
      config.model = "gpt-4o-mini"
    end

    allow(OpenAI::Client).to receive(:new).and_return(openai_client)
    allow(openai_client).to receive(:chat).and_return(spam_response)
  end

  describe "comment creation with AI moderation" do
    context "when the analysis job runs" do
      let(:perform_job) do
        Decidim::Ai::CommentModeration::AnalyzeCommentJob.perform_now(comment.id)
      end

      it "creates an AI moderation record" do
        expect { perform_job }
          .to change(Decidim::Ai::CommentModeration::CommentModeration, :count).by(1)

        moderation = comment.reload.ai_moderation
        expect(moderation).not_to be_nil
        expect(moderation.spam?).to be true
        expect(moderation.confidence_score).to eq(0.95)
      end

      it "calls OpenAI API with correct parameters" do
        perform_job

        expect(openai_client).to have_received(:chat).with(
          parameters: hash_including(
            model: "gpt-4o-mini",
            messages: array_including(
              hash_including(role: "system"),
              hash_including(role: "user", content: comment.translated_body)
            ),
            temperature: 0.3,
            response_format: { type: "json_object" }
          )
        )
      end

      context "with offensive content" do
        before do
          allow(openai_client).to receive(:chat).and_return(offensive_response)
        end

        it "correctly identifies offensive content" do
          perform_job

          moderation = comment.reload.ai_moderation
          expect(moderation.offensive?).to be true
          expect(moderation.spam?).to be false
          expect(moderation.requires_moderation?).to be true
        end
      end

      context "with clean content" do
        before do
          allow(openai_client).to receive(:chat).and_return(clean_response)
        end

        it "correctly identifies clean content" do
          perform_job

          moderation = comment.reload.ai_moderation
          expect(moderation.spam?).to be false
          expect(moderation.offensive?).to be false
          expect(moderation.requires_moderation?).to be false
        end
      end
    end
  end

  describe "duplicate analysis prevention" do
    let!(:existing_moderation) do
      create(:ai_comment_moderation, commentable: comment)
    end

    it "does not create duplicate moderation records" do
      expect do
        Decidim::Ai::CommentModeration::AnalyzeCommentJob.perform_now(comment.id)
      end.not_to change(Decidim::Ai::CommentModeration::CommentModeration, :count)
    end
  end

  describe "error handling" do
    context "when OpenAI API fails" do
      before do
        allow(openai_client).to receive(:chat).and_raise(StandardError.new("API Error"))
        allow(Rails.logger).to receive(:error)
      end

      it "handles errors gracefully" do
        expect do
          Decidim::Ai::CommentModeration::AnalyzeCommentJob.perform_now(comment.id)
        end.not_to raise_error

        expect(Rails.logger).to have_received(:error)
      end
    end

    context "when comment is deleted before analysis" do
      it "handles missing comment gracefully" do
        comment_id = comment.id
        comment.destroy

        expect do
          Decidim::Ai::CommentModeration::AnalyzeCommentJob.perform_now(comment_id)
        end.not_to raise_error
      end
    end
  end

  describe "association integration" do
    let!(:moderation) { create(:ai_comment_moderation, commentable: comment) }

    it "allows access to moderation from comment" do
      expect(comment.ai_moderation).to eq(moderation)
    end

    it "destroys moderation when comment is destroyed" do
      expect { comment.destroy }.to change(Decidim::Ai::CommentModeration::CommentModeration, :count).by(-1)
    end
  end

  describe "query scopes integration" do
    let!(:spam_comment) { create(:comment, commentable:, author:) }
    let!(:clean_comment) { create(:comment, commentable:, author:) }
    let!(:spam_moderation) { create(:ai_comment_moderation, :spam, commentable: spam_comment, confidence_score: 0.9) }
    let!(:clean_moderation) { create(:ai_comment_moderation, :clean, commentable: clean_comment, confidence_score: 0.8) }

    it "correctly filters spam comments" do
      spam_moderations = Decidim::Ai::CommentModeration::CommentModeration.spam_detected.high_confidence
      expect(spam_moderations).to include(spam_moderation)
      expect(spam_moderations).not_to include(clean_moderation)
    end

    it "correctly identifies comments requiring moderation" do
      expect(spam_moderation.requires_moderation?).to be true
      expect(clean_moderation.requires_moderation?).to be false
    end
  end
end
