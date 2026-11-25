# frozen_string_literal: true

require "rails_helper"

describe Decidim::ContentRenderers::MentionResourceRenderer do
  let(:organization) { create(:organization) }
  let(:component) { create(:proposal_component, organization:) }
  let(:proposal) { create(:proposal, component:) }
  let(:renderer) { described_class.new("See #{proposal.to_global_id}") }
  let(:fragment) { Loofah.fragment(renderer.render) }
  let(:mention_text) { fragment.at_css(".editor-mention span").text }
  let(:editor_fragment) { Loofah.fragment(renderer.render(editor: true)) }
  let(:editor_mention) { editor_fragment.at_css("span[data-type='mentionResource']") }

  around { |example| I18n.with_locale(:ja) { example.run } }

  before { proposal.update_column(:title, { "ja" => title }) } # rubocop:disable Rails/SkipsModelValidations

  context "when the title contains an ampersand" do
    let(:title) { "A & B" }

    it "escapes the title only once" do
      expect(mention_text).to eq("A & B")
    end

    it "escapes the title only once in the editor" do
      expect(editor_mention["data-label"]).to eq("A & B")
      expect(editor_mention.text).to eq("A & B")
      expect(editor_mention["data-id"]).to eq(proposal.to_global_id.to_s)
    end
  end

  context "when the title contains an entity" do
    let(:title) { "A &amp; B" }

    it "shows the entity as text" do
      expect(mention_text).to eq("A &amp; B")
      expect(editor_mention["data-label"]).to eq("A &amp; B")
    end
  end

  context "when the title contains HTML" do
    let(:title) { %(Check"><img src=x onerror="alert(1)">) }

    it "shows the title as text" do
      expect(mention_text).to eq(title)
      expect(fragment.css("img[onerror]")).to be_empty
    end

    it "shows the title as text in the editor" do
      expect(editor_mention["data-label"]).to eq(title)
      expect(editor_mention.text).to eq(title)
      expect(editor_fragment.css("img")).to be_empty
    end
  end

  context "when the title contains a blob reference and quotes" do
    let(:title) { %(gid://x/ActiveStorage::Blob/999999 " onmouseover="alert(1)" x=') }

    it "keeps the quotes inside the label in the editor" do
      expect(editor_mention.attributes.keys).to contain_exactly("data-type", "data-id", "data-label")
      expect(editor_mention["data-label"]).to eq(%( " onmouseover="alert(1)" x='))
    end
  end
end
