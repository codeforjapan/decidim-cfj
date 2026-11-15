# frozen_string_literal: true

require "rails_helper"

# Covers PgSearch::Features::Bigram in config/initializers/pg_search_override.rb.
describe Decidim::SearchableResource do
  describe ".global_search" do
    let(:organization) { create(:organization) }
    let!(:bicycle) { create(:searchable_resource, organization:, content_a: "駅前の駐輪場を増やしてほしい") }
    let!(:park) { create(:searchable_resource, organization:, content_a: "公園にベンチを置いてほしい") }

    it "finds resources by a part of Japanese text" do
      expect(described_class.global_search("駐輪場")).to contain_exactly(bicycle)
    end

    it "treats quotes and LIKE wildcards in the term as plain characters" do
      expect(described_class.global_search("'%")).to be_empty
    end
  end
end
