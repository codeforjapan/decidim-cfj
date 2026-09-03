# frozen_string_literal: true

require "rails_helper"

RSpec.describe Decidim::BulkUserImportSetting do
  subject(:settings) { described_class.new(organization:, email_domain:, enabled:) }

  let(:organization) { create(:organization) }
  let(:email_domain) { "chiba-mirai.test" }
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

  # ドットなしのドメインだと発行したアカウントがログイン画面の
  # メール形式チェック（Foundation Abide）で弾かれるため、TLD 相当を必須にする。
  context "when the domain has no dot" do
    ["chiba-mirai", "localhost"].each do |bad|
      it "rejects #{bad.inspect}" do
        settings.email_domain = bad
        expect(settings).not_to be_valid
      end
    end
  end

  context "when the domain has a label edge that breaks the email format" do
    ["chiba-.test", "chiba-mirai.", ".test", "chiba..test"].each do |bad|
      it "rejects #{bad.inspect}" do
        settings.email_domain = bad
        expect(settings).not_to be_valid
      end
    end
  end

  context "when the organization already has settings" do
    before { described_class.create!(organization:, email_domain: "other.test", enabled: false) }

    it { is_expected.not_to be_valid }
  end
end
