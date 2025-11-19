# frozen_string_literal: true

require "rails_helper"

module Decidim
  module Ai
    module CommentModeration
      describe CreateAiReport do
        subject { described_class.new(comment, ai_analysis_result) }

        let(:organization) { create(:organization) }
        let(:participatory_process) { create(:participatory_process, organization:) }
        let(:component) { create(:component, participatory_space: participatory_process) }
        let(:commentable) { create(:dummy_resource, component:) }
        let(:comment) { create(:comment, commentable:) }

        let(:ai_analysis_result) do
          {
            flagged:,
            decidim_reason:,
            confidence:,
            severity:,
            flagged_categories:,
            categories:,
            reason: ai_reason
          }
        end

        let(:flagged) { true }
        let(:decidim_reason) { "spam" }
        let(:confidence) { 0.9 }
        let(:severity) { "high" }
        let(:flagged_categories) { ["spam"] }
        let(:categories) { { "spam" => true, "offensive" => false, "inappropriate" => false } }
        let(:ai_reason) { "広告コンテンツです" }

        before do
          Decidim::Ai::CommentModeration.configure do |config|
            config.openai_api_key = "test-key-123"
            config.enabled_hosts = [organization.host]
            config.confidence_threshold = 0.8
          end
        end

        describe "#call" do
          context "when all conditions are met" do
            it "broadcasts :ok" do
              expect { subject.call }.to broadcast(:ok)
            end

            it "creates a report" do
              expect { subject.call }.to change(Decidim::Report, :count).by(1)
            end

            it "creates a moderation if not exists" do
              expect { subject.call }.to change(Decidim::Moderation, :count).by(1)
            end

            it "uses AI system user as reporter" do
              subject.call
              report = Decidim::Report.last
              expect(report.user.email).to match(/ai-moderation@/)
              expect(report.user.nickname).to match(/ai_moderator_/)
            end

            it "sets correct reason" do
              subject.call
              report = Decidim::Report.last
              expect(report.reason).to eq("spam")
            end

            it "includes AI analysis details" do
              subject.call
              report = Decidim::Report.last
              expect(report.details).to include("AI自動検出")
              expect(report.details).to include("90.0%")
            end
          end

          context "when offensive instead of spam" do
            let(:decidim_reason) { "offensive" }
            let(:flagged_categories) { ["offensive"] }
            let(:categories) { { "spam" => false, "offensive" => true, "inappropriate" => false } }

            it "sets offensive as reason" do
              subject.call
              report = Decidim::Report.last
              expect(report.reason).to eq("offensive")
            end
          end

          context "when confidence is below threshold" do
            let(:confidence) { 0.5 }

            it "broadcasts :invalid" do
              expect { subject.call }.to broadcast(:invalid)
            end

            it "does not create a report" do
              expect { subject.call }.not_to change(Decidim::Report, :count)
            end
          end

          context "when not flagged" do
            let(:flagged) { false }
            let(:decidim_reason) { nil }
            let(:flagged_categories) { [] }
            let(:categories) { { "spam" => false, "offensive" => false, "inappropriate" => false } }

            it "broadcasts :invalid" do
              expect { subject.call }.to broadcast(:invalid)
            end
          end

          context "when comment is already reported by AI" do
            let(:ai_user) { SystemAiUser.new(organization).find_or_create_ai_user }

            before do
              # Create an existing AI report
              moderation = Decidim::Moderation.create!(
                reportable: comment,
                participatory_space: participatory_process
              )
              Decidim::Report.create!(
                moderation:,
                user: ai_user,
                reason: "spam",
                details: "Previous AI report"
              )
            end

            it "broadcasts :invalid" do
              expect { subject.call }.to broadcast(:invalid)
            end

            it "does not create another report" do
              expect { subject.call }.not_to change(Decidim::Report, :count)
            end
          end

          context "when comment has human reports" do
            before do
              # Create a human report
              human_user = create(:user, organization:)
              moderation = Decidim::Moderation.create!(
                reportable: comment,
                participatory_space: participatory_process
              )
              Decidim::Report.create!(
                moderation:,
                user: human_user,
                reason: "offensive",
                details: "Human report"
              )
            end

            it "still creates AI report" do
              expect { subject.call }.to change(Decidim::Report, :count).by(1)
            end

            it "broadcasts :ok" do
              expect { subject.call }.to broadcast(:ok)
            end
          end
        end
      end
    end
  end
end
