# frozen_string_literal: true

require "rails_helper"

RSpec.describe Decidim::AdminLoginCodeForm do
  subject(:form) { described_class.from_params(admin_login_code: { code: }) }

  context "with six digits" do
    let(:code) { "012345" }

    it { is_expected.to be_valid }
  end

  context "with surrounding spaces" do
    let(:code) { " 012345 " }

    it { is_expected.to be_valid }
  end

  context "with a blank code" do
    let(:code) { "" }

    it { is_expected.to be_invalid }
  end

  context "with five digits" do
    let(:code) { "12345" }

    it { is_expected.to be_invalid }
  end

  context "with full-width digits" do
    let(:code) { "１２３４５６" }

    it { is_expected.to be_invalid }
  end
end
