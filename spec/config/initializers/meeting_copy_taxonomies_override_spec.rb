# frozen_string_literal: true

require "rails_helper"

# decidim-meetings 0.30.9 の CopyMeeting は Meeting.create! に
# `taxonomies: form.taxonomies` を渡すが、フォームが返すのは
# Decidim::Taxonomy ではなくタクソノミーの id 配列なので、
# コンポーネントにタクソノミーフィルタがあると必ず
# ActiveRecord::AssociationTypeMismatch になる。
RSpec.describe "Decidim::Meetings::Admin::CopyMeeting taxonomies override" do
  subject(:command) { Decidim::Meetings::Admin::CopyMeeting.new(form, meeting) }

  let(:organization) { create(:organization) }
  let(:user) { create(:user, :confirmed, :admin, organization:) }
  let(:participatory_process) { create(:participatory_process, organization:) }
  let(:current_component) do
    create(:component, manifest_name: :meetings, participatory_space: participatory_process)
  end
  let!(:meeting) { create(:meeting, component: current_component) }

  let(:root_taxonomy) { create(:taxonomy, organization:) }
  let!(:taxonomy) { create(:taxonomy, parent: root_taxonomy, organization:) }
  let(:taxonomy_filter) { create(:taxonomy_filter, root_taxonomy:) }
  let!(:taxonomy_filter_item) { create(:taxonomy_filter_item, taxonomy_filter:, taxonomy_item: taxonomy) }

  # 複製フォームの select は未選択でも hidden の空文字を送ってくるので、
  # 本番と同じく先頭に "" が入った配列を渡す。
  let(:submitted_taxonomies) { [""] }

  let(:params) do
    {
      meeting: {
        title: { ja: "懇親会", en: "Get-together" },
        description: { ja: "<p>複製のテストです。</p>", en: "<p>A copy test.</p>" },
        location: { ja: "会議室", en: "Meeting room" },
        location_hints: { ja: "", en: "" },
        type_of_meeting: "in_person",
        address: "スマートシティAiCT",
        latitude: 37.4922258,
        longitude: 139.9301371,
        start_time: 1.day.from_now,
        end_time: 1.day.from_now + 2.hours,
        taxonomies: submitted_taxonomies,
        registration_type: "registration_disabled",
        private_meeting: "0",
        transparent: "0",
        comments_enabled: "1"
      }
    }
  end

  let(:form) do
    Decidim::Meetings::Admin::MeetingForm.from_params(params, current_component:).with_context(
      current_organization: organization,
      current_component:,
      current_participatory_space: participatory_process,
      current_user: user
    )
  end

  before do
    current_component.update!(settings: { taxonomy_filters: [taxonomy_filter.id] })
  end

  it "はフォームからタクソノミーの id 配列を受け取る" do
    expect(form).to be_valid
    expect(form.taxonomies).to all(be_nil.or(be_a(Integer)))
  end

  context "when no taxonomy is selected" do
    it "は例外を出さずに複製する" do
      expect { command.call }.to change(Decidim::Meetings::Meeting, :count).by(1)
    end

    it "はタクソノミーなしの複製を作る" do
      command.call

      copied_meeting = Decidim::Meetings::Meeting.order(:id).last
      expect(copied_meeting.taxonomies).to be_empty
      expect(translated(copied_meeting.title, locale: :ja)).to eq("懇親会")
    end
  end

  context "when a taxonomy is selected" do
    let(:submitted_taxonomies) { ["", taxonomy.id.to_s] }

    it "は例外を出さずに複製する" do
      expect { command.call }.to change(Decidim::Meetings::Meeting, :count).by(1)
    end

    it "は選択されたタクソノミーを複製先に引き継ぐ" do
      command.call

      copied_meeting = Decidim::Meetings::Meeting.order(:id).last
      expect(copied_meeting.taxonomies).to eq([taxonomy])
    end
  end
end
