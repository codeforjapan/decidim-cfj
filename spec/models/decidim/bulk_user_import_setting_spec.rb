# frozen_string_literal: true

require "rails_helper"

RSpec.describe Decidim::BulkUserImportSetting do
  subject(:settings) { described_class.new(organization:, email_domain:, enabled:) }

  let(:organization) { create(:organization) }
  let(:email_domain) { "chiba-mirai" }
  let(:enabled) { true }

  it { is_expected.to be_valid }

  context "when enabled without a domain" do
    let(:email_domain) { nil }

    it { is_expected.not_to be_valid }
  end

  context "when disabled without a domain" do
    let(:email_domain) { nil }
    let(:enabled) { false }

    it { is_expected.to be_valid }
  end

  context "when the domain would break the email format" do
    ["chiba mirai", "chiba@mirai", "Chiba-Mirai", "-chiba"].each do |bad|
      it "rejects #{bad.inspect}" do
        settings.email_domain = bad
        expect(settings).not_to be_valid
      end
    end
  end

  context "when the organization already has settings" do
    before { described_class.create!(organization:, email_domain: "other", enabled: false) }

    it { is_expected.not_to be_valid }
  end
end
