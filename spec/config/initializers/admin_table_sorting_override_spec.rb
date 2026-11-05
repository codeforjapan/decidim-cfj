# frozen_string_literal: true

require "rails_helper"

# Backport of decidim/decidim#16978 (itself a backport of #16831).
# See config/initializers/admin_table_sorting_override.rb for the why and the
# removal steps.
RSpec.describe "admin table sorting override" do
  let(:organization) { create(:organization) }
  let(:admin) { build(:user, :admin, :confirmed, organization:) }

  describe "Decidim::Moderation" do
    it "allows sorting by report_count" do
      expect(Decidim::Moderation.ransackable_attributes).to include("report_count")
    end
  end

  describe "Decidim::UserModeration" do
    it "allows sorting by created_at and report_count" do
      expect(Decidim::UserModeration.ransackable_attributes).to include("created_at", "report_count")
    end
  end

  describe "Decidim::ParticipatorySpacePrivateUser" do
    it "allows admins to sort by published" do
      expect(Decidim::ParticipatorySpacePrivateUser.ransackable_attributes(admin)).to include("published")
    end

    it "does not allow non-admins" do
      expect(Decidim::ParticipatorySpacePrivateUser.ransackable_attributes(nil)).to be_empty
    end
  end

  describe "Decidim::UserBaseEntity" do
    it "allows admins to sort by role, user_moderation_report_count and created_at" do
      expect(Decidim::UserBaseEntity.ransackable_attributes(admin))
        .to include("role", "user_moderation_report_count", "created_at")
    end

    it "allows regular users to sort by created_at but not the admin only keys" do
      attributes = Decidim::UserBaseEntity.ransackable_attributes(build(:user, organization:))

      expect(attributes).to include("created_at")
      expect(attributes).not_to include("role", "user_moderation_report_count")
    end
  end

  describe "sorting users by report count" do
    subject(:result) do
      Decidim::User.where(organization:).ransack({ s: "user_moderation_report_count asc" }, auth_object: admin).result
    end

    let!(:without_moderation) { create(:user, :confirmed, organization:) }
    let!(:with_few_reports) { create(:user, :confirmed, organization:) }
    let!(:with_many_reports) { create(:user, :confirmed, organization:) }

    before do
      create(:user_moderation, user: with_few_reports, report_count: 3)
      create(:user_moderation, user: with_many_reports, report_count: 9)
    end

    it "treats a missing moderation as zero reports" do
      expect(result.map(&:id)).to eq([without_moderation.id, with_few_reports.id, with_many_reports.id])
    end
  end

  describe "Decidim::Meetings::Meeting" do
    it "allows admins to sort by start_time, end_time, closed and translated_title" do
      expect(Decidim::Meetings::Meeting.ransackable_attributes(admin))
        .to include("start_time", "end_time", "closed", "translated_title")
    end

    it "does not allow non-admins to use the admin only keys" do
      expect(Decidim::Meetings::Meeting.ransackable_attributes(nil))
        .to eq(%w(description id_string search_text title))
    end

    context "with meetings" do
      let(:participatory_process) { create(:participatory_process, organization:) }
      let(:component) { create(:component, manifest_name: :meetings, participatory_space: participatory_process) }
      let!(:open_meeting) { create(:meeting, component:) }
      let!(:closed_meeting) { create(:meeting, :closed, component:) }

      it "sorts closed meetings first with the closed ransacker" do
        result = Decidim::Meetings::Meeting.where(component:).ransack({ s: "closed desc" }, auth_object: admin).result

        expect(result.first).to eq(closed_meeting)
        expect(result.last).to eq(open_meeting)
      end
    end
  end

  describe "Decidim::Proposals::Proposal" do
    it "allows sorting by translated_title, state_published and valuation_assignments_count" do
      expect(Decidim::Proposals::Proposal.ransackable_attributes)
        .to include("translated_title", "state_published", "valuation_assignments_count")
    end
  end
end
