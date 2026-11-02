# frozen_string_literal: true

require "rails_helper"
require "decidim/system/test/factories"

RSpec.describe Decidim::AdminLoginCodeMailer do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, :confirmed, organization:) }

  describe "#locked_notice" do
    subject(:mail) { described_class.locked_notice(system_admin, user, Time.current) }

    let(:system_admin) { create(:admin) }

    it "tells the system admin who is locked and how to unlock" do
      expect(mail.to).to eq([system_admin.email])
      expect(mail.body.encoded).to include(user.email)
      expect(mail.body.encoded).to include("admin_login_code:unlock DECIDIM_ORGANIZATION_ID=#{organization.id}")
    end

    context "when the email has characters special to the shell" do
      let(:user) { create(:user, :admin, :confirmed, organization:, email: "a`id`b@example.org") }

      it "quotes it in the command" do
        expect(mail.body.encoded).to include("EMAIL=a\\`id\\`b@example.org")
      end
    end
  end

  describe "#locked" do
    subject(:mail) { described_class.locked(user) }

    it "is sent to the user" do
      expect(mail.to).to eq([user.email])
    end
  end
end
