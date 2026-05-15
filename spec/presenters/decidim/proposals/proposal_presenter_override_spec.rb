# frozen_string_literal: true

require "rails_helper"

# rubocop:disable Rails/SkipsModelValidations
module Decidim
  module Proposals
    describe ProposalPresenter do
      let(:organization) { create(:organization) }
      let(:component) { create(:proposal_component, organization:) }
      let(:user) { create(:user, :confirmed, organization:) }
      let(:proposal) { create(:proposal, component:, users: [user]) }
      let(:presenter) { described_class.new(proposal) }

      describe "#title" do
        context "when the stored title contains a script tag" do
          before do
            proposal.update_column(:title, { I18n.locale.to_s => "Hi<script>alert(1)</script>" })
          end

          it "escapes the tag with the default arguments" do
            expect(presenter.title).to include("&lt;script&gt;")
            expect(presenter.title).not_to include("<script>")
          end

          it "escapes the tag when called with html_escape: true" do
            expect(presenter.title(html_escape: true)).to include("&lt;script&gt;")
            expect(presenter.title(html_escape: true)).not_to include("<script>")
          end

          it "escapes the tag when called with html_escape: false (forced safe)" do
            expect(presenter.title(html_escape: false)).to include("&lt;script&gt;")
            expect(presenter.title(html_escape: false)).not_to include("<script>")
          end

          it "marks the result html_safe" do
            expect(presenter.title).to be_html_safe
          end
        end

        context "when the stored title contains an event-handler attribute" do
          before do
            proposal.update_column(:title, { I18n.locale.to_s => "Hi <img src=x onerror=alert(1)>" })
          end

          it "escapes angle brackets so the tag cannot execute" do
            expect(presenter.title).not_to match(/<img\b/i)
            expect(presenter.title).to include("&lt;img")
          end
        end

        context "when the stored title is plain text" do
          before do
            proposal.update_column(:title, { I18n.locale.to_s => "Hello world" })
          end

          it "preserves the text unchanged" do
            expect(presenter.title.to_s).to eq("Hello world")
          end
        end
      end

      describe "#id_and_title" do
        before do
          proposal.update_column(:title, { I18n.locale.to_s => "Hi<script>alert(1)</script>" })
        end

        it "escapes the title portion regardless of html_escape argument" do
          expect(presenter.id_and_title(html_escape: false)).to include("&lt;script&gt;")
          expect(presenter.id_and_title(html_escape: false)).not_to include("<script>")
        end
      end
    end
  end
end
# rubocop:enable Rails/SkipsModelValidations
