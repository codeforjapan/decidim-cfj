# frozen_string_literal: true

require "rails_helper"
require "decidim/system/test/factories"

RSpec.describe Decidim::AdminLoginCodes::VerifyCode do
  subject(:command) { described_class.new(form) }

  let(:user) { create(:user, :admin, :confirmed) }
  let!(:issued_code) { Decidim::AdminLoginCode.issue!(user) }
  let(:form) do
    Decidim::AdminLoginCodeForm.from_params(admin_login_code: { code: }).with_context(current_user: user)
  end

  context "with the issued code" do
    let(:code) { issued_code }

    it "broadcasts ok and consumes the code" do
      expect { command.call }.to broadcast(:ok)
      expect(Decidim::AdminLoginCode.find_by(user:).code_digest).to be_nil
    end
  end

  context "with another code" do
    let(:code) { issued_code == "000000" ? "111111" : "000000" }

    it "broadcasts invalid and counts the attempt" do
      expect { command.call }.to broadcast(:invalid)
      expect(Decidim::AdminLoginCode.find_by(user:).failed_attempts).to eq(1)
    end
  end

  context "when this wrong code reaches the total limit" do
    let(:code) { issued_code == "000000" ? "111111" : "000000" }
    let!(:system_admin) { create(:admin) }

    before do
      Decidim::AdminLoginCode.find_by(user:).update!(total_failed_attempts: Decidim::AdminLoginCode::MAX_TOTAL_FAILED_ATTEMPTS - 1)
    end

    it "locks the admin panel and notifies the user and the system admins" do
      expect { command.call }.to broadcast(:locked)
        .and have_enqueued_mail(Decidim::AdminLoginCodeMailer, :locked).with(user)
        .and have_enqueued_mail(Decidim::AdminLoginCodeMailer, :locked_notice).with(system_admin, user, anything)
      expect(Decidim::AdminLoginCode.find_by(user:)).to be_locked
    end
  end

  context "with a malformed code" do
    let(:code) { "abc" }

    it "broadcasts invalid without counting an attempt" do
      expect { command.call }.to broadcast(:invalid)
      expect(Decidim::AdminLoginCode.find_by(user:).failed_attempts).to eq(0)
    end
  end

  context "when the user of the form has no code" do
    let(:code) { issued_code }
    let(:form) do
      Decidim::AdminLoginCodeForm.from_params(admin_login_code: { code: })
                                 .with_context(current_user: create(:user, :admin, :confirmed))
    end

    it "broadcasts invalid" do
      expect { command.call }.to broadcast(:invalid)
    end
  end
end
