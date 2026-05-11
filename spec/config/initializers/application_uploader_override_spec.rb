# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Decidim::ApplicationUploader#remote_url= override" do
  let(:organization) { create(:organization) }
  let(:model) do
    create(:attachment, attached_to: create(:participatory_process, organization:))
  end
  let(:uploader) { model.attached_uploader(:file) }
  let(:url) { "https://cdn.example.com/file.png" }
  let(:host) { "cdn.example.com" }
  let(:public_ip) { "203.0.113.10" }
  let(:body) { "FILEDATA" }
  let(:original_filename) { model.file.filename.to_s }

  before do
    allow(Resolv).to receive(:getaddresses).with(host).and_return([public_ip])
  end

  context "with a public URL serving any content type" do
    before do
      stub_request(:get, url).to_return(
        status: 200, body:, headers: { "Content-Type" => "application/pdf" }
      )
    end

    it "replaces the attached file" do
      uploader.remote_url = url
      expect(model.file.filename.to_s).to eq("file.png")
      expect(model.file.download).to eq(body)
    end
  end

  context "with a URL pointing to a private IP" do
    let(:url) { "http://internal.example.com/file.png" }

    before do
      allow(Resolv).to receive(:getaddresses).with("internal.example.com").and_return(["10.0.0.5"])
    end

    it "raises SocketError and does not replace the file" do
      original = original_filename
      expect { uploader.remote_url = url }.to raise_error(SocketError)
      expect(model.file.filename.to_s).to eq(original)
    end
  end

  context "with a non-HTTP scheme" do
    let(:url) { "file:///etc/passwd" }

    it "raises SocketError and does not replace the file" do
      original = original_filename
      expect { uploader.remote_url = url }.to raise_error(SocketError)
      expect(model.file.filename.to_s).to eq(original)
    end
  end

  context "when the upstream returns 404" do
    before { stub_request(:get, url).to_return(status: 404) }

    it "raises SocketError and does not replace the file" do
      original = original_filename
      expect { uploader.remote_url = url }.to raise_error(SocketError)
      expect(model.file.filename.to_s).to eq(original)
    end
  end

  context "when the URL has no path" do
    let(:url) { "https://cdn.example.com" }

    before do
      stub_request(:get, url).to_return(status: 200, body:, headers: { "Content-Type" => "image/png" })
    end

    it "uses the fallback filename" do
      uploader.remote_url = url
      expect(model.file.filename.to_s).to eq("remote_file")
    end
  end
end
