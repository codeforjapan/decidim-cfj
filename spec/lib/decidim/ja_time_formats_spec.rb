# frozen_string_literal: true

require "rails_helper"

describe "Japanese time formats" do
  let(:time) { Time.zone.local(2026, 11, 25, 9, 5) }

  [:decidim_month, :decidim_month_and_year, :time_of_day_with_time_zone].each do |format|
    it "defines #{format}" do
      expect { I18n.l(time, format:, locale: :ja, raise: true) }.not_to raise_error
    end
  end

  it "describes the date format in the same order as decidim_short" do
    expect(I18n.t("date.formats.decidim_short", locale: :ja)).to eq("%Y/%m/%d")
    expect(I18n.t("date.formats.help.date_format", locale: :ja)).to eq("フォーマット: yyyy/mm/dd")
  end
end
