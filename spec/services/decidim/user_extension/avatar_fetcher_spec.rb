# frozen_string_literal: true

require "rails_helper"

RSpec.describe Decidim::UserExtension::AvatarFetcher do
  subject(:result) { described_class.call(url) }

  let(:url) { "https://cdn.example.com/avatar.png" }
  let(:host) { "cdn.example.com" }
  let(:public_ip) { "203.0.113.10" }
  let(:body) { "PNGDATA" }
  let(:image_headers) { { "Content-Type" => "image/png" } }

  before { stub_dns(host, public_ip) }

  def stub_dns(hostname, *addresses)
    allow(Resolv).to receive(:getaddresses).with(hostname).and_return(addresses)
  end

  describe ".call" do
    context "when the URL is blank" do
      let(:url) { "" }

      it { is_expected.to be_nil }
    end

    context "with a malformed URL" do
      let(:url) { "http://[::1" }

      it { is_expected.to be_nil }
    end

    context "with a non-HTTP scheme" do
      let(:url) { "file:///etc/passwd" }

      it { is_expected.to be_nil }
    end

    context "when the host resolves to loopback" do
      before { stub_dns(host, "127.0.0.1") }

      it { is_expected.to be_nil }
    end

    context "when the host resolves to the AWS metadata endpoint" do
      before { stub_dns(host, "169.254.169.254") }

      it { is_expected.to be_nil }
    end

    context "when the host resolves to an RFC1918 private address" do
      before { stub_dns(host, "10.0.0.5") }

      it { is_expected.to be_nil }
    end

    context "when the host resolves to 0.0.0.0" do
      before { stub_dns(host, "0.0.0.0") }

      it { is_expected.to be_nil }
    end

    context "when one of multiple resolved addresses is private" do
      before { stub_dns(host, "203.0.113.10", "10.0.0.5") }

      it "rejects the request" do
        expect(result).to be_nil
      end
    end

    context "when DNS resolution returns no addresses" do
      before { stub_dns(host) }

      it { is_expected.to be_nil }
    end

    context "when DNS resolution fails" do
      before { allow(Resolv).to receive(:getaddresses).with(host).and_raise(Resolv::ResolvError) }

      it { is_expected.to be_nil }
    end

    context "when the response is an allowed image" do
      before { stub_request(:get, url).to_return(status: 200, body:, headers: image_headers) }

      it "returns an IO and filename" do
        io, filename = result
        expect(io.read).to eq(body)
        expect(filename).to eq("avatar.png")
      end
    end

    context "when the Content-Type is text/html" do
      before do
        stub_request(:get, url).to_return(
          status: 200, body: "<html></html>", headers: { "Content-Type" => "text/html" }
        )
      end

      it { is_expected.to be_nil }
    end

    context "when the Content-Type is missing" do
      before { stub_request(:get, url).to_return(status: 200, body:) }

      it { is_expected.to be_nil }
    end

    context "when the Content-Type has parameters" do
      before do
        stub_request(:get, url).to_return(
          status: 200, body:, headers: { "Content-Type" => "image/jpeg; charset=binary" }
        )
      end

      it "matches against the media type only" do
        io, = result
        expect(io.read).to eq(body)
      end
    end

    context "when the response is 404" do
      before { stub_request(:get, url).to_return(status: 404) }

      it { is_expected.to be_nil }
    end

    context "when Content-Length declares an oversize body" do
      before do
        stub_request(:get, url).to_return(
          status: 200,
          body: "x",
          headers: image_headers.merge("Content-Length" => (described_class::MAX_BYTES + 1).to_s)
        )
      end

      it "rejects without reading the body" do
        expect(result).to be_nil
      end
    end

    context "when Content-Length lies and the streamed body exceeds the limit" do
      before do
        oversize = "x" * (described_class::MAX_BYTES + 1)
        stub_request(:get, url).to_return(
          status: 200,
          body: oversize,
          headers: image_headers.merge("Content-Length" => "10")
        )
      end

      it "aborts mid-stream" do
        expect(result).to be_nil
      end
    end

    context "when the request times out" do
      before { stub_request(:get, url).to_timeout }

      it { is_expected.to be_nil }
    end

    context "when the path is empty" do
      let(:url) { "https://cdn.example.com" }

      before { stub_request(:get, url).to_return(status: 200, body:, headers: image_headers) }

      it "falls back to a default filename" do
        _io, filename = result
        expect(filename).to eq("avatar")
      end
    end

    context "with a redirect to a public URL" do
      let(:final_url) { "https://cdn2.example.com/avatar.png" }

      before do
        stub_dns("cdn2.example.com", "203.0.113.20")
        stub_request(:get, url).to_return(status: 302, headers: { "Location" => final_url })
        stub_request(:get, final_url).to_return(status: 200, body:, headers: image_headers)
      end

      it "follows the redirect" do
        io, = result
        expect(io.read).to eq(body)
      end
    end

    context "with a redirect to a private IP" do
      let(:final_url) { "http://internal.example.com/avatar.png" }

      before do
        stub_dns("internal.example.com", "10.0.0.5")
        stub_request(:get, url).to_return(status: 302, headers: { "Location" => final_url })
      end

      it "rejects the redirected request" do
        expect(result).to be_nil
      end
    end

    context "with a redirect chain exceeding the limit" do
      before do
        chain = (0..described_class::MAX_REDIRECTS).map { |i| "https://cdn.example.com/hop#{i}.png" }
        full_chain = [url] + chain
        full_chain.each_cons(2) do |from, to|
          stub_request(:get, from).to_return(status: 302, headers: { "Location" => to })
        end
      end

      it { is_expected.to be_nil }
    end

    context "with a redirect missing the Location header" do
      before { stub_request(:get, url).to_return(status: 302) }

      it { is_expected.to be_nil }
    end

    context "when a fetch is rejected" do
      let(:url) { "file:///etc/passwd" }

      it "logs a warning with the URL and reason" do
        expect(Rails.logger).to receive(:warn) do |&block|
          expect(block.call).to match(/skipped url=.*file:.*reason=unsafe_uri/)
        end
        result
      end
    end
  end

  describe ".call with allowed_content_types: nil" do
    subject(:result) { described_class.call(url, allowed_content_types: nil) }

    context "when the response is text/html" do
      before do
        stub_request(:get, url).to_return(
          status: 200, body:, headers: { "Content-Type" => "text/html" }
        )
      end

      it "still returns the body" do
        io, = result
        expect(io.read).to eq(body)
      end
    end

    context "when the Content-Type is missing" do
      before { stub_request(:get, url).to_return(status: 200, body:) }

      it "still returns the body" do
        io, = result
        expect(io.read).to eq(body)
      end
    end

    context "when the host resolves to a private IP" do
      before { stub_dns(host, "10.0.0.5") }

      it "is still rejected by the SSRF guard" do
        expect(result).to be_nil
      end
    end
  end

  describe ".call with default_filename:" do
    subject(:result) { described_class.call(url, allowed_content_types: nil, default_filename: "import") }

    let(:url) { "https://cdn.example.com" }

    before { stub_request(:get, url).to_return(status: 200, body:) }

    it "uses the provided fallback filename" do
      _io, filename = result
      expect(filename).to eq("import")
    end
  end
end
