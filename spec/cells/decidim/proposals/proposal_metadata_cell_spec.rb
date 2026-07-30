# frozen_string_literal: true

require "rails_helper"

# rubocop:disable Rails/SkipsModelValidations
# update_column intentionally bypasses REGEXP_NAME so we can simulate names
# inserted before validation was tightened (legacy rows, OmniAuth provider
# data, etc.). The point of these tests is to verify defense-in-depth at the
# rendering layer regardless of the input validation.

module Decidim
  module Proposals
    describe ProposalMetadataCell, type: :cell do
      controller Decidim::PagesController

      let(:organization) { create(:organization) }
      let(:component) { create(:proposal_component, organization:) }
      let(:user) { create(:user, :confirmed, organization:) }
      let(:proposal) { create(:proposal, component:, users: [user]) }
      let(:cell_instance) { cell("decidim/proposals/proposal_metadata", proposal) }

      before do
        allow(controller).to receive(:current_organization).and_return(organization)
      end

      describe "#items_for_map" do
        subject(:items) { cell_instance.send(:items_for_map) }

        let(:coauthor_item) { items.first }

        context "when the coauthor name contains an anchor tag" do
          before { user.update_column(:name, '<a href="http://evil.example">click</a>') }

          it "HTML-escapes the tag in the popup text" do
            expect(coauthor_item[:text]).to include("&lt;a")
            expect(coauthor_item[:text]).not_to match(/<a\s/)
          end
        end

        context "when the coauthor name is plain" do
          before { user.update_column(:name, "Alice") }

          it "preserves the name as-is" do
            expect(coauthor_item[:text]).to eq("Alice")
          end
        end

        context "when serialized to JSON for the marker popup" do
          before { user.update_column(:name, '<a href="http://evil.example">click</a>') }

          it "produces no tag-opening sequence that innerHTML would interpret as HTML" do
            # The popup template uses {{html text}}, so the JSON string is inserted
            # as HTML. Browsers decode entity references in innerHTML but do NOT
            # re-tokenize the decoded characters as tags, so escaped entities are
            # safe even through {{html ...}}.
            json = items.to_json
            expect(json).to include("\\u0026lt;a")
            expect(json).not_to match(/[^\\]<a\s/)
          end
        end
      end
    end
  end
end
# rubocop:enable Rails/SkipsModelValidations
