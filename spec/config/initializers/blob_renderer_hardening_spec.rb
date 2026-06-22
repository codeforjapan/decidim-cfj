# frozen_string_literal: true

require "rails_helper"

RSpec.describe BlobRendererHardening do
  let(:renderer) { Decidim::ContentRenderers::BlobRenderer.new("") }

  describe "ALLOWED_VARIATION_KEYS" do
    it "matches the Rails 7.1.5.2 supported_image_processing_methods size" do
      expect(described_class::ALLOWED_VARIATION_KEYS.size).to eq(284)
    end

    it "excludes the transformation methods" do
      %w(apply loader saver).each do |key|
        expect(described_class::ALLOWED_VARIATION_KEYS).not_to include(key)
      end
    end

    it "includes the transformation methods actually used by Decidim" do
      %w(resize resize_to_fit resize_to_limit resize_to_fill resize_and_pad format quality define).each do |key|
        expect(described_class::ALLOWED_VARIATION_KEYS).to include(key)
      end
    end
  end

  describe "#sanitize_variation" do
    subject { renderer.send(:sanitize_variation, input) }

    context "with a Hash containing only allowed keys" do
      let(:input) { { "resize_to_fit" => [100, 100], "format" => "png" } }

      it { is_expected.to eq(input) }
    end

    context "with a Hash containing disallowed keys" do
      let(:input) { { "loader" => { "evil" => 1 }, "saver" => {}, "apply" => "x", "resize_to_fit" => [100, 100] } }

      it "strips the disallowed keys and keeps the allowed ones" do
        expect(subject).to eq("resize_to_fit" => [100, 100])
      end
    end

    context "with a Hash containing only disallowed keys" do
      let(:input) { { "loader" => { "x" => 1 }, "saver" => {} } }

      it { is_expected.to eq({}) }
    end

    context "with Symbol keys" do
      let(:input) { { resize_and_pad: [32, 32], format: :png, loader: { x: 1 } } }

      it "compares keys as strings" do
        expect(subject).to eq(resize_and_pad: [32, 32], format: :png)
      end
    end

    context "with a non-Hash input" do
      [nil, "named_variant", :thumb].each do |value|
        context "when #{value.inspect}" do
          let(:input) { value }

          it { is_expected.to eq(value) }
        end
      end
    end
  end

  describe "integration with BlobRenderer" do
    it "is prepended into Decidim::ContentRenderers::BlobRenderer" do
      expect(Decidim::ContentRenderers::BlobRenderer.ancestors).to include(described_class)
    end

    it "keeps blob_url and local_blob_url as protected methods" do
      expect(Decidim::ContentRenderers::BlobRenderer.protected_method_defined?(:blob_url)).to be(true)
      expect(Decidim::ContentRenderers::BlobRenderer.protected_method_defined?(:local_blob_url)).to be(true)
    end

    it "keeps sanitize_variation as a private method" do
      expect(Decidim::ContentRenderers::BlobRenderer.private_method_defined?(:sanitize_variation)).to be(true)
    end
  end
end
