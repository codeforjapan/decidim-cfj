# frozen_string_literal: true

require "rails_helper"

module Decidim
  describe NotificationToMailerPresenter, type: :presenter do
    subject { described_class.new(notification) }

    context "with a daily frequency" do
      let(:creating_date) { Time.parse("Wed, 1 Sep 2021 21:00:00 UTC +00:00").in_time_zone }
      let(:notification) { create(:notification, created_at: creating_date) }

      describe "#date_time" do
        it "returns the hour formated" do
          allow(subject).to receive(:frequency).and_return(:daily)
          expect(subject.date_time).to eq("21:00")
        end
      end
    end

    context "with a daily frequency in timezone of Japan" do
      let(:creating_date) { Time.zone.parse("Wed, 1 Sep 2021 21:00:00 +00:00").in_time_zone("Asia/Tokyo") }
      let(:notification) do
        create(:notification, created_at: creating_date) do |notification|
          org = notification.resource.organization
          org.time_zone = "Asia/Tokyo"
          org.save!
        end
      end

      describe "#date_time" do
        it "returns the hour formated" do
          allow(subject).to receive(:frequency).and_return(:daily)
          expect(subject.date_time).to eq("06:00")
        end
      end
    end

    context "with a weekly frequency" do
      let(:creating_date) { Time.parse("Wed, 1 Sep 2021 21:00:00 UTC +00:00").in_time_zone }
      let(:notification) { create(:notification, created_at: creating_date) }

      describe "#date_time" do
        it "returns the date formated" do
          allow(subject).to receive(:frequency).and_return(:weekly)
          expect(subject.date_time).to eq("01/09/2021 21:00")
        end
      end
    end
  end
end
