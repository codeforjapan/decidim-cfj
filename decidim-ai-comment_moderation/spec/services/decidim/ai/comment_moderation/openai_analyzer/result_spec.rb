# frozen_string_literal: true

require "rails_helper"
require_relative "../../../../../fixtures/openai_responses"

module Decidim
  module Ai
    module CommentModeration
      class OpenaiAnalyzer
        RSpec.describe Result, type: :model do
          include OpenaiResponses

          let(:comment_text) { "This is a test comment" }

          describe "#initialize" do
            context "with valid response" do
              let(:result) { described_class.new(offensive_response, comment_text) }

              it "parses the response correctly" do
                expect(result.flagged?).to be true
                expect(result.categories).to be_a(Hash)
                expect(result.flagged_categories).to include("offensive")
              end
            end

            context "with invalid response" do
              let(:response) { { "results" => [] } }

              before do
                allow(Rails.logger).to receive(:error)
              end

              it "raises an error" do
                expect { described_class.new(response, comment_text) }.to raise_error(StandardError, /Failed to parse chat API response/)
              end
            end
          end

          describe "#flagged?" do
            it "returns true for flagged content" do
              result = described_class.new(offensive_response, comment_text)
              expect(result.flagged?).to be true
            end

            it "returns false for clean content" do
              result = described_class.new(clean_response, comment_text)
              expect(result.flagged?).to be false
            end
          end

          describe "#confidence" do
            it "returns the highest category score" do
              result = described_class.new(offensive_response, comment_text)
              expect(result.confidence).to eq(0.88)
            end

            it "returns 0.0 for clean content" do
              result = described_class.new(clean_response, comment_text)
              expect(result.confidence).to eq(0.01)
            end
          end

          describe "#severity" do
            context "with high-risk categories" do
              it "returns high severity" do
                result = described_class.new(offensive_response, comment_text)
                expect(result.severity).to eq("high")
              end
            end

            context "with low confidence scores" do
              it "returns low severity" do
                result = described_class.new(clean_response, comment_text)
                expect(result.severity).to eq("low")
              end
            end

            context "with medium confidence" do
              it "returns medium severity" do
                result = described_class.new(low_confidence_response, comment_text)
                expect(result.severity).to eq("low") # 0.45 < 0.5
              end
            end
          end

          describe "#decidim_reason" do
            it "returns offensive for harassment content" do
              result = described_class.new(offensive_response, comment_text)
              expect(result.decidim_reason).to eq("offensive")
            end

            it "returns spam for spam content" do
              result = described_class.new(spam_response, comment_text)
              expect(result.decidim_reason).to eq("spam")
            end

            it "returns does_not_belong for inappropriate content" do
              result = described_class.new(inappropriate_response, comment_text)
              expect(result.decidim_reason).to eq("does_not_belong")
            end

            it "returns nil for clean content" do
              result = described_class.new(clean_response, comment_text)
              expect(result.decidim_reason).to be_nil
            end
          end


          describe "#requires_moderation?" do
            it "returns true for flagged high-confidence content" do
              allow(Decidim::Ai::CommentModeration).to receive(:confidence_threshold).and_return(0.8)
              result = described_class.new(offensive_response, comment_text)
              expect(result.requires_moderation?).to be true
            end

            it "returns false for low-confidence content" do
              allow(Decidim::Ai::CommentModeration).to receive(:confidence_threshold).and_return(0.8)
              result = described_class.new(low_confidence_response, comment_text)
              expect(result.requires_moderation?).to be false
            end

            it "returns false for clean content" do
              result = described_class.new(clean_response, comment_text)
              expect(result.requires_moderation?).to be false
            end
          end


          describe "#to_h" do
            let(:result) { described_class.new(offensive_response, comment_text) }

            it "returns hash representation" do
              hash = result.to_h
              expect(hash).to be_a(Hash)
              expect(hash[:flagged]).to be true
              expect(hash[:categories]).to be_a(Hash)
              expect(hash[:decidim_reason]).to eq("offensive")
              expect(hash[:confidence]).to eq(0.88)
              expect(hash[:severity]).to eq("high")
              expect(hash[:flagged_categories]).to include("offensive")
            end
          end

          describe "#to_json" do
            let(:result) { described_class.new(offensive_response, comment_text) }

            it "returns JSON representation" do
              json_string = result.to_h.to_json
              parsed = JSON.parse(json_string)
              expect(parsed["flagged"]).to be true
              expect(parsed["decidim_reason"]).to eq("offensive")
            end
          end

        end
      end
    end
  end
end