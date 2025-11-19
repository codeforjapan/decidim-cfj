# frozen_string_literal: true

require "rails_helper"
require_relative "../../../../fixtures/openai_responses"

module Decidim
  module Ai
    module CommentModeration
      RSpec.describe OpenaiAnalyzer, type: :service do
        include OpenaiResponses

        let(:organization) { create(:organization) }
        let(:participatory_process) { create(:participatory_process, organization:) }
        let(:component) { create(:component, participatory_space: participatory_process, manifest_name: "dummy") }
        let(:commentable) { create(:dummy_resource, component:) }
        let(:author) { create(:user, organization:) }
        let(:comment) { create(:comment, commentable:, author:) }
        let(:openai_client) { instance_double(OpenAI::Client) }
        let(:analyzer) { described_class.new(comment) }

        before do
          # Configure the module
          Decidim::Ai::CommentModeration.configure do |config|
            config.openai_api_key = "test-key-123"
            config.model = "gpt-4o-mini"
          end

          # Configure OpenAI globally (simulating what engine.rb does)
          OpenAI.configure do |c|
            c.access_token = "test-key-123"
          end

          allow(OpenAI::Client).to receive(:new).with(no_args).and_return(openai_client)
        end

        describe "#initialize" do
          it "creates an analyzer with a comment" do
            expect(analyzer.instance_variable_get(:@comment)).to eq(comment)
          end
        end

        describe "#analyze" do
          context "when API key is not present" do
            before do
              Decidim::Ai::CommentModeration.config.openai_api_key = nil
            end

            it "returns nil" do
              expect(analyzer.analyze).to be_nil
            end
          end

          context "when API key is present" do
            context "with successful API response (spam content)" do
              before do
                allow(openai_client).to receive(:chat).and_return(spam_response)
              end

              it "calls OpenAI Chat API with correct parameters" do
                analyzer.analyze

                expect(openai_client).to have_received(:chat).with(
                  parameters: hash_including(
                    model: "gpt-4o-mini",
                    messages: array_including(
                      hash_including(role: "system"),
                      hash_including(role: "user", content: comment.translated_body)
                    )
                  )
                )
              end

              it "returns Result object with parsed data" do
                result = analyzer.analyze

                expect(result).to be_a(OpenaiAnalyzer::Result)
                expect(result.flagged?).to be true
                expect(result.decidim_reason).to eq("spam")
                expect(result.confidence).to eq(0.95)
                expect(result.flagged_categories).to eq(["spam"])
              end
            end

            context "with clean content response" do
              before do
                allow(openai_client).to receive(:chat).and_return(clean_response)
              end

              it "returns Result object for clean content" do
                result = analyzer.analyze

                expect(result).to be_a(OpenaiAnalyzer::Result)
                expect(result.flagged?).to be false
                expect(result.decidim_reason).to be_nil
                expect(result.confidence).to eq(0.01)
                expect(result.flagged_categories).to eq([])
              end
            end

            context "with offensive content response" do
              before do
                allow(openai_client).to receive(:chat).and_return(offensive_response)
              end

              it "returns Result object for offensive content" do
                result = analyzer.analyze

                expect(result).to be_a(OpenaiAnalyzer::Result)
                expect(result.flagged?).to be true
                expect(result.decidim_reason).to eq("offensive")
                expect(result.confidence).to eq(0.88)
                expect(result.flagged_categories).to eq(["offensive"])
              end
            end

            context "with malformed response" do
              before do
                allow(openai_client).to receive(:chat).and_return(malformed_response)
                allow(Rails.logger).to receive(:error)
              end

              it "logs error and returns nil" do
                result = analyzer.analyze

                expect(result).to be_nil
                expect(Rails.logger).to have_received(:error).with(/Failed to parse chat API response/).at_least(:once)
              end
            end

            context "when API call raises an exception" do
              before do
                allow(openai_client).to receive(:chat).and_raise(StandardError.new("API Error"))
                allow(Rails.logger).to receive(:error)
              end

              it "logs error and returns nil" do
                result = analyzer.analyze

                expect(result).to be_nil
                expect(Rails.logger).to have_received(:error).with(/AI Analysis failed for comment #{comment.id}: API Error/)
              end
            end

            context "with custom model configuration" do
              before do
                Decidim::Ai::CommentModeration.config.model = "gpt-4o"
                allow(openai_client).to receive(:chat).and_return(clean_response)
              end

              it "uses the configured model" do
                analyzer.analyze

                expect(openai_client).to have_received(:chat).with(
                  parameters: hash_including(model: "gpt-4o")
                )
              end
            end
          end
        end
      end
    end
  end
end
