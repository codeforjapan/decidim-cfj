# frozen_string_literal: true

require "rails_helper"

module Decidim
  module Ai
    describe CommentModeration do
      let(:organization) { create(:organization) }
      let(:participatory_process) { create(:participatory_process, organization:) }
      let(:component) { create(:component, participatory_space: participatory_process, manifest_name: "dummy") }
      let(:commentable) { create(:dummy_resource, component:) }
      let(:author) { create(:user, organization:) }
      let(:comment) { create(:comment, commentable:, author:) }

      subject { create(:ai_comment_moderation, commentable: comment) }

      describe "associations" do
        it "belongs to commentable" do
          expect(subject.commentable).to eq(comment)
        end
      end

      describe "validations" do
        it "validates presence of commentable" do
          moderation = build(:ai_comment_moderation, commentable: nil)
          expect(moderation).not_to be_valid
          expect(moderation.errors[:commentable]).to include("must exist")
        end

        it "validates confidence_score range" do
          moderation = build(:ai_comment_moderation, confidence_score: 1.5)
          expect(moderation).not_to be_valid

          moderation = build(:ai_comment_moderation, confidence_score: -0.1)
          expect(moderation).not_to be_valid

          moderation = build(:ai_comment_moderation, confidence_score: 0.8)
          expect(moderation).to be_valid
        end
      end

      describe "scopes" do
        let!(:high_confidence) { create(:ai_comment_moderation, confidence_score: 0.9) }
        let!(:low_confidence) { create(:ai_comment_moderation, confidence_score: 0.5) }
        let!(:spam_detected) { create(:ai_comment_moderation, :spam) }
        let!(:offensive_detected) { create(:ai_comment_moderation, :offensive) }

        describe ".high_confidence" do
          it "returns moderations with confidence > 0.8" do
            expect(CommentModeration::CommentModeration.high_confidence).to include(high_confidence)
            expect(CommentModeration::CommentModeration.high_confidence).not_to include(low_confidence)
          end
        end

        describe ".spam_detected" do
          it "returns moderations marked as spam" do
            expect(CommentModeration::CommentModeration.spam_detected).to include(spam_detected)
            expect(CommentModeration::CommentModeration.spam_detected).not_to include(offensive_detected)
          end
        end

        describe ".offensive_detected" do
          it "returns moderations marked as offensive" do
            expect(CommentModeration::CommentModeration.offensive_detected).to include(offensive_detected)
            expect(CommentModeration::CommentModeration.offensive_detected).not_to include(spam_detected)
          end
        end
      end

      describe "#spam?" do
        context "when analysis_result indicates spam" do
          subject { create(:ai_comment_moderation, :spam) }

          it "returns true" do
            expect(subject.spam?).to be true
          end
        end

        context "when analysis_result does not indicate spam" do
          subject { create(:ai_comment_moderation, :clean) }

          it "returns false" do
            expect(subject.spam?).to be false
          end
        end
      end

      describe "#offensive?" do
        context "when analysis_result indicates offensive content" do
          subject { create(:ai_comment_moderation, :offensive) }

          it "returns true" do
            expect(subject.offensive?).to be true
          end
        end

        context "when analysis_result does not indicate offensive content" do
          subject { create(:ai_comment_moderation, :clean) }

          it "returns false" do
            expect(subject.offensive?).to be false
          end
        end
      end

      describe "#requires_moderation?" do
        context "with high confidence spam" do
          subject { create(:ai_comment_moderation, :spam, confidence_score: 0.9) }

          it "returns true" do
            expect(subject.requires_moderation?).to be true
          end
        end

        context "with high confidence offensive content" do
          subject { create(:ai_comment_moderation, :offensive, confidence_score: 0.85) }

          it "returns true" do
            expect(subject.requires_moderation?).to be true
          end
        end

        context "with low confidence" do
          subject { create(:ai_comment_moderation, :spam, confidence_score: 0.5) }

          it "returns false" do
            expect(subject.requires_moderation?).to be false
          end
        end

        context "with clean content" do
          subject { create(:ai_comment_moderation, :clean, confidence_score: 0.9) }

          it "returns false" do
            expect(subject.requires_moderation?).to be false
          end
        end
      end

      describe "#high_confidence?" do
        context "with confidence score > 0.8" do
          subject { create(:ai_comment_moderation, confidence_score: 0.9) }

          it "returns true" do
            expect(subject.high_confidence?).to be true
          end
        end

        context "with confidence score <= 0.8" do
          subject { create(:ai_comment_moderation, confidence_score: 0.7) }

          it "returns false" do
            expect(subject.high_confidence?).to be false
          end
        end

        context "with nil confidence score" do
          subject { create(:ai_comment_moderation, confidence_score: nil) }

          it "returns false" do
            expect(subject.high_confidence?).to be false
          end
        end
      end
    end
  end
end
