# frozen_string_literal: true

require "rails_helper"

RSpec.describe Decidim::AdminLoginCodes::SendCode do
  subject(:command) { described_class.new(user) }

  let(:user) { create(:user, :admin, :confirmed) }

  before { ActionMailer::Base.deliveries.clear }

  it "issues a code and emails it" do
    expect { command.call }.to broadcast(:ok)
    expect(Decidim::AdminLoginCode.find_by(user:)).to be_present
    expect(ActionMailer::Base.deliveries.map(&:to)).to eq([[user.email]])
  end

  context "when the admin panel is locked" do
    before { Decidim::AdminLoginCode.create!(user:, locked_at: Time.current) }

    it "does not send a code" do
      expect { command.call }.to broadcast(:skipped)
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  context "when the email cannot be sent" do
    before { allow(Decidim::AdminLoginCodeMailer).to receive(:code).and_raise(Net::ReadTimeout) }

    it "discards the code but keeps the time for the resend interval" do
      expect { command.call }.to broadcast(:invalid)
      expect(Decidim::AdminLoginCode.find_by(user:)).to have_attributes(code_digest: nil, sent_at: be_present)
    end
  end
end
