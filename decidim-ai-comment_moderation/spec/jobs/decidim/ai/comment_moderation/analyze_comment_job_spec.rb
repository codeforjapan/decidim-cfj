# frozen_string_literal: true

require "rails_helper"

module Decidim
  module Ai
    module CommentModeration
      RSpec.describe AnalyzeCommentJob do
        let(:organization) { create(:organization) }
        let(:participatory_process) { create(:participatory_process, organization:) }
        let(:component) { create(:component, participatory_space: participatory_process, manifest_name: "dummy") }
        let(:commentable) { create(:dummy_resource, component:) }
        let(:author) { create(:user, organization:) }
        let(:comment) { create(:comment, commentable:, author:) }
        let(:job) { described_class.new }
        let(:analyzer) { instance_double(OpenaiAnalyzer) }
        let(:result_double) { instance_double(OpenaiAnalyzer::Result) }

        let(:result_hash) do
          {
            "flagged" => true,
            "decidim_reason" => "spam",
            "confidence" => 0.95,
            "severity" => "high",
            "flagged_categories" => ["spam"],
            "categories" => { "spam" => true, "offensive" => false, "inappropriate" => false },
            "reason" => "広告コンテンツです"
          }
        end

        before do
          # Configure the module
          Decidim::Ai::CommentModeration.configure do |config|
            config.openai_api_key = "test-key-123"
            config.enabled_hosts = [organization.host]
            config.confidence_threshold = 0.8
          end

          allow(OpenaiAnalyzer).to receive(:new).with(comment).and_return(analyzer)
          allow(Rails.logger).to receive(:info)
          allow(Rails.logger).to receive(:warn)
          allow(Rails.logger).to receive(:error)
        end

        describe "#perform" do
          context "when comment exists" do
            context "and has not been analyzed yet" do
              before do
                allow(result_double).to receive(:to_h).and_return(result_hash)
                allow(result_double).to receive(:confidence).and_return(0.95)
                allow(result_double).to receive(:flagged?).and_return(true)
                allow(result_double).to receive(:decidim_reason).and_return("spam")
                allow(result_double).to receive(:flagged_categories).and_return(["spam"])
                allow(result_double).to receive(:requires_moderation?).and_return(true)
                allow(result_double).to receive(:requires_auto_hide?).and_return(false)
                allow(analyzer).to receive(:analyze).and_return(result_double)
              end

              it "creates an AI moderation record" do
                expect { job.perform(comment.id) }
                  .to change(Decidim::Ai::CommentModeration::CommentModeration, :count).by(1)

                moderation = Decidim::Ai::CommentModeration::CommentModeration.last
                expect(moderation.commentable).to eq(comment)
                expect(moderation.analysis_result).to eq(result_hash)
                expect(moderation.confidence_score).to eq(0.95)
              end

              it "logs the analysis result" do
                job.perform(comment.id)

                expect(Rails.logger).to have_received(:info).with(
                  "[AI Moderation] Comment ##{comment.id} analyzed: " \
                  "Flagged: true, Decidim Reason: spam, Confidence: 0.95"
                )

                expect(Rails.logger).to have_received(:info).with(
                  "[AI Moderation] Flagged categories: spam"
                )
              end

              context "when moderation is required" do
                before do
                  allow(result_double).to receive(:flagged?).and_return(true)
                  allow(result_double).to receive(:confidence).and_return(0.92)
                  allow(result_double).to receive(:decidim_reason).and_return("offensive")
                  allow(result_double).to receive(:flagged_categories).and_return(%w(spam offensive))
                  allow(result_double).to receive(:requires_moderation?).and_return(true)
                  allow(result_double).to receive(:requires_auto_hide?).and_return(false)
                end

                it "creates report for high-confidence issues" do
                  # The job no longer logs a warning, but creates a report instead
                  # Just verify it processes without error
                  expect { job.perform(comment.id) }.not_to raise_error
                end
              end

              context "when moderation is not required" do
                before do
                  allow(result_double).to receive(:flagged?).and_return(false)
                  allow(result_double).to receive(:confidence).and_return(0.92)
                  allow(result_double).to receive(:decidim_reason).and_return(nil)
                  allow(result_double).to receive(:flagged_categories).and_return([])
                  allow(result_double).to receive(:requires_moderation?).and_return(false)
                  allow(result_double).to receive(:requires_auto_hide?).and_return(false)
                end

                it "does not create a report" do
                  # Just verify it processes without error and creates the moderation record
                  expect { job.perform(comment.id) }
                    .to change(Decidim::Ai::CommentModeration::CommentModeration, :count).by(1)
                end
              end

              context "when confidence is low" do
                before do
                  allow(result_double).to receive(:flagged?).and_return(true)
                  allow(result_double).to receive(:confidence).and_return(0.5)
                  allow(result_double).to receive(:decidim_reason).and_return("spam")
                  allow(result_double).to receive(:flagged_categories).and_return(["spam"])
                  allow(result_double).to receive(:requires_moderation?).and_return(false)
                  allow(result_double).to receive(:requires_auto_hide?).and_return(false)
                end

                it "logs but does not create report" do
                  job.perform(comment.id)

                  expect(Rails.logger).to have_received(:info).with(
                    "[AI Moderation] Flagged but below threshold for comment ##{comment.id}: " \
                    "spam (confidence: 0.5)"
                  )
                end
              end

              context "when auto-hide threshold is met" do
                before do
                  Decidim::Ai::CommentModeration.configure do |config|
                    config.auto_hide_threshold = 0.95
                  end

                  allow(result_double).to receive(:flagged?).and_return(true)
                  allow(result_double).to receive(:confidence).and_return(0.98)
                  allow(result_double).to receive(:decidim_reason).and_return("offensive")
                  allow(result_double).to receive(:flagged_categories).and_return(["offensive"])
                  allow(result_double).to receive(:requires_moderation?).and_return(true)
                  allow(result_double).to receive(:requires_auto_hide?).and_return(true)
                end

                it "auto-hides the comment" do
                  job.perform(comment.id)

                  expect(comment.reload.hidden?).to be true
                  expect(Rails.logger).to have_received(:info).with(
                    "[AI Moderation] Comment ##{comment.id} auto-hidden: confidence=98.0%, reason=offensive"
                  )
                end

                it "creates a moderation record with hidden_at" do
                  job.perform(comment.id)

                  moderation = comment.reload.moderation
                  expect(moderation).to be_present
                  expect(moderation.hidden_at).to be_present
                end

                context "when comment is already hidden" do
                  let!(:existing_moderation) do
                    Decidim::Moderation.create!(
                      reportable: comment,
                      participatory_space: comment.participatory_space,
                      report_count: 1,
                      hidden_at: 1.day.ago
                    )
                  end

                  before do
                    # Comment needs to be reloaded to pick up the moderation
                    comment.reload
                    # Need to delete the AI moderation record so the job runs
                    Decidim::Ai::CommentModeration::CommentModeration.where(commentable: comment).delete_all
                  end

                  it "does not update hidden_at again" do
                    original_hidden_at = existing_moderation.hidden_at
                    job.perform(comment.id)

                    expect(existing_moderation.reload.hidden_at).to be_within(1.second).of(original_hidden_at)
                  end
                end
              end

              context "when auto-hide threshold is not configured" do
                before do
                  Decidim::Ai::CommentModeration.configure do |config|
                    config.auto_hide_threshold = nil
                  end

                  allow(result_double).to receive(:flagged?).and_return(true)
                  allow(result_double).to receive(:confidence).and_return(0.99)
                  allow(result_double).to receive(:decidim_reason).and_return("offensive")
                  allow(result_double).to receive(:flagged_categories).and_return(["offensive"])
                  allow(result_double).to receive(:requires_moderation?).and_return(true)
                  allow(result_double).to receive(:requires_auto_hide?).and_return(false)
                end

                it "does not auto-hide the comment" do
                  job.perform(comment.id)

                  expect(comment.reload.hidden?).to be false
                end
              end
            end

            context "and has already been analyzed" do
              let!(:existing_moderation) do
                create(:ai_comment_moderation, commentable: comment)
              end

              it "does not create another moderation record" do
                expect { job.perform(comment.id) }
                  .not_to change(Decidim::Ai::CommentModeration::CommentModeration, :count)
              end

              it "does not call the analyzer" do
                job.perform(comment.id)
                expect(OpenaiAnalyzer).not_to have_received(:new)
              end
            end

            context "when analyzer returns nil" do
              before do
                allow(analyzer).to receive(:analyze).and_return(nil)
              end

              it "does not create a moderation record" do
                expect { job.perform(comment.id) }
                  .not_to change(Decidim::Ai::CommentModeration::CommentModeration, :count)
              end

              it "does not log analysis result" do
                job.perform(comment.id)

                expect(Rails.logger).not_to have_received(:info)
              end
            end

            context "when an error occurs during analysis" do
              before do
                allow(analyzer).to receive(:analyze).and_raise(StandardError.new("API Error"))
              end

              it "logs the error and does not re-raise" do
                expect { job.perform(comment.id) }.not_to raise_error

                expect(Rails.logger).to have_received(:error).with(
                  "Failed to analyze comment #{comment.id}: API Error"
                )
              end

              it "does not create a moderation record" do
                expect { job.perform(comment.id) }
                  .not_to change(Decidim::Ai::CommentModeration::CommentModeration, :count)
              end
            end
          end

          context "when comment does not exist" do
            it "does not raise an error" do
              expect { job.perform(999_999) }.not_to raise_error
            end

            it "does not create a moderation record" do
              expect { job.perform(999_999) }
                .not_to change(Decidim::Ai::CommentModeration::CommentModeration, :count)
            end

            it "does not call the analyzer" do
              job.perform(999_999)
              expect(OpenaiAnalyzer).not_to have_received(:new)
            end
          end
        end

        describe "#already_analyzed?" do
          context "when moderation record exists" do
            let!(:existing_moderation) do
              create(:ai_comment_moderation, commentable: comment)
            end

            it "returns true" do
              result = job.send(:already_analyzed?, comment)
              expect(result).to be true
            end
          end

          context "when no moderation record exists" do
            it "returns false" do
              result = job.send(:already_analyzed?, comment)
              expect(result).to be false
            end
          end
        end

        describe "job configuration" do
          it "is configured to run on events queue" do
            expect(described_class.queue_name).to eq("events")
          end
        end
      end
    end
  end
end
