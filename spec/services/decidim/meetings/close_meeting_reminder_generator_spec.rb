# frozen_string_literal: true

require "rails_helper"

RSpec.describe Decidim::Meetings::CloseMeetingReminderGenerator do
  subject(:generator) { described_class.new }

  describe "#generate" do
    context "when multiple organizations exist (cross-organization bug)" do
      let(:org_a) { create(:organization) }
      let(:org_b) { create(:organization) }

      let!(:admin_a) { create(:user, :admin, organization: org_a) }
      let!(:admin_b) { create(:user, :admin, organization: org_b) }

      let(:space_a) { create(:participatory_process, :with_steps, organization: org_a) }
      let(:component_a) { create(:meeting_component, participatory_space: space_a) }

      let(:space_b) { create(:participatory_process, :with_steps, organization: org_b) }
      let(:component_b) { create(:meeting_component, participatory_space: space_b) }

      let!(:official_meeting_a) do
        create(:meeting, :published, :official, component: component_a, end_time: 3.days.ago)
      end
      let!(:official_meeting_b) do
        create(:meeting, :published, :official, component: component_b, end_time: 3.days.ago)
      end

      it "org_b の公式ミーティングリマインダーを org_b の管理者にのみ送る" do
        queued_records = []
        allow(Decidim::Meetings::SendCloseMeetingReminderJob).to receive(:perform_later) do |record|
          queued_records << record
        end

        generator.generate

        org_b_meeting_reminders = queued_records.select { |r| r.remindable == official_meeting_b }
        users = org_b_meeting_reminders.map { |r| r.reminder.user }
        expect(users).not_to include(admin_a)
        expect(users).to include(admin_b)
      end
    end
  end
end
