# frozen_string_literal: true

require "rails_helper"

describe Decidim::ContentRenderers::MentionResourceRenderer do
  let(:organization) { create(:organization) }
  let(:component) { create(:proposal_component, organization:) }
  let(:proposal) { create(:proposal, component:) }
  let(:fragment) { Loofah.fragment(described_class.new("See #{proposal.to_global_id}").render) }
  let(:mention_text) { fragment.at_css(".editor-mention span").text }

  around { |example| I18n.with_locale(:ja) { example.run } }

  before { proposal.update_column(:title, { "ja" => title }) } # rubocop:disable Rails/SkipsModelValidations

  context "when the title contains an ampersand" do
    let(:title) { "A & B" }

    it "escapes the title only once" do
      expect(mention_text).to eq("A & B")
    end
  end

  context "when the title contains HTML" do
    let(:title) { %(Check"><img src=x onerror="alert(1)">) }

    it "shows the title as text" do
      expect(mention_text).to eq(title)
      expect(fragment.css("img[onerror]")).to be_empty
    end
  end
end
