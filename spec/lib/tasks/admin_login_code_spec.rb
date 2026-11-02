# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "admin_login_code rake tasks" do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, :confirmed, organization:) }
  let(:run) { Rake::Task["admin_login_code:unlock"].invoke }

  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?("admin_login_code:unlock")
    Rake::Task["admin_login_code:unlock"].reenable
    ENV["DECIDIM_ORGANIZATION_ID"] = organization.id.to_s
    ENV["EMAIL"] = user.email
  end

  after { %w(DECIDIM_ORGANIZATION_ID EMAIL).each { |key| ENV.delete(key) } }

  context "when the admin panel is locked" do
    before { Decidim::AdminLoginCode.create!(user:, total_failed_attempts: 10, locked_at: Time.current) }

    it "unlocks it" do
      expect { run }.to output(/Unlocked/).to_stdout

      expect(Decidim::AdminLoginCode.find_by(user:)).to have_attributes(locked_at: nil, total_failed_attempts: 0)
    end
  end

  context "when the admin panel is not locked" do
    it "aborts" do
      expect { run }.to raise_error(SystemExit).and output.to_stderr
    end
  end

  context "when the user belongs to another organization" do
    before { ENV["DECIDIM_ORGANIZATION_ID"] = create(:organization).id.to_s }

    it "aborts" do
      expect { run }.to raise_error(SystemExit).and output.to_stderr
    end
  end
end
