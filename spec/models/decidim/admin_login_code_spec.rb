# frozen_string_literal: true

require "rails_helper"

RSpec.describe Decidim::AdminLoginCode do
  let(:user) { create(:user, :admin, :confirmed) }
  let!(:code) { described_class.issue!(user) }
  let(:login_code) { described_class.find_by(user:) }

  it "stores only the digest" do
    expect(code).to match(/\A\d{6}\z/)
    expect(login_code.code_digest).not_to include(code)
  end

  it "does not issue a code within the resend interval" do
    expect(described_class.issue!(user)).to be_nil
    expect(login_code.verify(code)).to be(true)
  end

  it "issues a new code right after the previous one is used" do
    login_code.verify(code)

    expect(described_class.issue!(user)).to be_present
  end

  it "keeps one code per user" do
    login_code.update!(sent_at: 2.minutes.ago)
    described_class.issue!(user)

    expect(described_class.where(user:).count).to eq(1)
  end

  it "accepts the code once" do
    expect(login_code.verify(code)).to be(true)
    expect(login_code.reload.code_digest).to be_nil
    expect(login_code.verify(code)).to be(false)
  end

  it "rejects a wrong code and counts the attempt" do
    expect(login_code.verify(code == "000000" ? "111111" : "000000")).to be(false)
    expect(login_code.reload.failed_attempts).to eq(1)
  end

  context "when wrong codes reach the total limit" do
    let(:wrong_code) { code == "000000" ? "111111" : "000000" }

    before do
      login_code.update!(total_failed_attempts: described_class::MAX_TOTAL_FAILED_ATTEMPTS - 1)
      login_code.verify(wrong_code)
    end

    it "locks the admin panel once" do
      expect(login_code.lock_if_exhausted!).to be(true)
      expect(login_code.lock_if_exhausted!).to be(false)
      expect(login_code.reload).to be_locked
    end

    it "does not issue new codes while locked" do
      login_code.lock_if_exhausted!
      login_code.update!(sent_at: 2.minutes.ago)

      expect(described_class.issue!(user)).to be_nil
    end

    it "is unlocked with unlock!" do
      login_code.lock_if_exhausted!
      described_class.unlock!(user)

      expect(login_code.reload).not_to be_locked
      expect(login_code.total_failed_attempts).to eq(0)
      expect(described_class.issue!(user)).to be_present
    end
  end

  it "does not accept the right code once locked" do
    login_code.update!(locked_at: Time.current)

    expect(login_code.verify(code)).to be(false)
  end

  it "keeps the total of wrong codes when a new code is issued" do
    login_code.verify(code == "000000" ? "111111" : "000000")
    login_code.update!(sent_at: 2.minutes.ago)
    described_class.issue!(user)

    expect(login_code.reload).to have_attributes(failed_attempts: 0, total_failed_attempts: 1)
  end

  it "resets the total of wrong codes when the right code is entered" do
    login_code.verify(code == "000000" ? "111111" : "000000")
    login_code.verify(code)

    expect(login_code.reload.total_failed_attempts).to eq(0)
  end

  context "when the code has expired" do
    before { login_code.update!(sent_at: 11.minutes.ago) }

    it "rejects the code" do
      expect(login_code.verify(code)).to be(false)
    end
  end

  context "when the attempts are used up" do
    before { login_code.update!(failed_attempts: described_class::MAX_FAILED_ATTEMPTS) }

    it "rejects the right code" do
      expect(login_code.verify(code)).to be(false)
    end
  end

  context "when the code belongs to another user" do
    let(:other_user) { create(:user, :admin, :confirmed, organization: user.organization) }
    let(:other_code) { described_class.find_by(user: other_user) }

    before { described_class.issue!(other_user) }

    it "rejects it" do
      expect(other_code.verify(code)).to be(false)
    end
  end
end
