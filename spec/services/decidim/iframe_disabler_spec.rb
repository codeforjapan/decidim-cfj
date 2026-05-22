# frozen_string_literal: true

require "rails_helper"

describe Decidim::IframeDisabler do
  subject { described_class.new(html).perform }

  context "when frame-src allows all domains" do
    before do
      allow(Decidim.config.content_security_policies_extra).to receive(:dig)
        .with("frame-src")
        .and_return(["*"])
    end

    let(:html) { '<iframe src="https://example.com/embed"></iframe>' }

    it "keeps the iframe" do
      expect(subject).to include('<iframe src="https://example.com/embed">')
    end
  end

  context "when frame-src has allowed domains" do
    before do
      allow(Decidim.config.content_security_policies_extra).to receive(:dig)
        .with("frame-src")
        .and_return(%w(https://www.youtube.com www.youtube-nocookie.com))
    end

    context "with allowed domain" do
      let(:html) { '<iframe src="https://www.youtube.com/embed/abc123"></iframe>' }

      it "keeps the iframe" do
        expect(subject).to include('<iframe src="https://www.youtube.com/embed/abc123">')
      end
    end

    context "with allowed subdomain" do
      let(:html) { '<iframe src="https://subdomain.www.youtube-nocookie.com/embed"></iframe>' }

      it "keeps the iframe" do
        expect(subject).to include('<iframe src="https://subdomain.www.youtube-nocookie.com/embed">')
      end
    end

    context "with not allowed domain" do
      let(:html) { '<iframe src="https://example.com/embed"></iframe>' }

      it "disables the iframe" do
        expect(subject).to include('class="disabled-iframe"')
        expect(subject).to include("disabled-iframe")
        expect(subject).not_to include('<iframe src="https://example.com/embed"></iframe>')
      end
    end
  end

  context "when frame-src is empty or not configured" do
    before do
      allow(Decidim.config.content_security_policies_extra).to receive(:dig)
        .with("frame-src")
        .and_return(nil)
    end

    let(:html) { '<iframe src="https://example.com/embed"></iframe>' }

    it "disables all iframes" do
      expect(subject).to include('class="disabled-iframe"')
      expect(subject).not_to include('<iframe src="https://example.com/embed"></iframe>')
    end
  end

  context "with invalid iframe src" do
    before do
      allow(Decidim.config.content_security_policies_extra).to receive(:dig)
        .with("frame-src")
        .and_return(%w(https://www.youtube.com))
    end

    let(:html) { '<iframe src=":::invalid:::"></iframe>' }

    it "disables the iframe" do
      expect(subject).to include('class="disabled-iframe"')
    end
  end

  context "with multiple iframes" do
    before do
      allow(Decidim.config.content_security_policies_extra).to receive(:dig)
        .with("frame-src")
        .and_return(%w(https://www.youtube.com))
    end

    let(:html) do
      '<div><iframe src="https://www.youtube.com/embed/abc"></iframe><iframe src="https://example.com/embed"></iframe></div>'
    end

    it "keeps allowed iframe and disables others" do
      expect(subject).to include('<iframe src="https://www.youtube.com/embed/abc">')
      expect(subject).to include('class="disabled-iframe"')
      expect(subject).not_to include('<iframe src="https://example.com/embed"></iframe>')
    end
  end

  context "with CSP keyword values" do
    context "when frame-src contains 'none'" do
      before do
        allow(Decidim.config.content_security_policies_extra).to receive(:dig)
          .with("frame-src")
          .and_return(["'none'"])
      end

      let(:html) { '<iframe src="https://www.youtube.com/embed/abc"></iframe>' }

      it "disables all iframes" do
        expect(subject).to include('class="disabled-iframe"')
      end
    end
  end

  context "with CSP scheme values" do
    context "when frame-src allows https: scheme" do
      before do
        allow(Decidim.config.content_security_policies_extra).to receive(:dig)
          .with("frame-src")
          .and_return(["https:"])
      end

      context "with https iframe" do
        let(:html) { '<iframe src="https://example.com/embed"></iframe>' }

        it "keeps the iframe" do
          expect(subject).to include('<iframe src="https://example.com/embed">')
        end
      end

      context "with http iframe" do
        let(:html) { '<iframe src="http://example.com/embed"></iframe>' }

        it "disables the iframe" do
          expect(subject).to include('class="disabled-iframe"')
        end
      end
    end
  end

  context "with wildcard subdomains" do
    before do
      allow(Decidim.config.content_security_policies_extra).to receive(:dig)
        .with("frame-src")
        .and_return(["*.example.com"])
    end

    context "with matching subdomain" do
      let(:html) { '<iframe src="https://api.example.com/embed"></iframe>' }

      it "keeps the iframe" do
        expect(subject).to include('<iframe src="https://api.example.com/embed">')
      end
    end

    context "with base domain" do
      let(:html) { '<iframe src="https://example.com/embed"></iframe>' }

      it "keeps the iframe" do
        expect(subject).to include('<iframe src="https://example.com/embed">')
      end
    end

    context "with non-matching domain" do
      let(:html) { '<iframe src="https://other.com/embed"></iframe>' }

      it "disables the iframe" do
        expect(subject).to include('class="disabled-iframe"')
      end
    end
  end

  context "with CSP domain with port" do
    before do
      allow(Decidim.config.content_security_policies_extra).to receive(:dig)
        .with("frame-src")
        .and_return(["https://example.com:443"])
    end

    context "and matching domain (port ignored for hostname)" do
      let(:html) { '<iframe src="https://example.com/embed"></iframe>' }

      it "keeps the iframe" do
        expect(subject).to include('<iframe src="https://example.com/embed">')
      end
    end
  end

  context "with CSP domain with path" do
    before do
      allow(Decidim.config.content_security_policies_extra).to receive(:dig)
        .with("frame-src")
        .and_return(["https://example.com/path/"])
    end

    context "and matching domain (path ignored for hostname)" do
      let(:html) { '<iframe src="https://example.com/different/path"></iframe>' }

      it "keeps the iframe" do
        expect(subject).to include('<iframe src="https://example.com/different/path">')
      end
    end
  end
end
