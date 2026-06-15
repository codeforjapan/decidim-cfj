# frozen_string_literal: true

require "rails_helper"

describe "Mobile logo display", js: true do
  let(:organization) { create(:organization, name: { en: "Test Organization" }) }

  before do
    switch_to_host(organization.host)
    I18n.locale = :ja
    # Selenium reuses the same browser window across system specs. The examples
    # below shrink it to a mobile viewport, so remember the original size and
    # restore it afterwards; otherwise later specs run at 375px wide and fail to
    # find elements that are hidden or repositioned in the mobile layout.
    @original_window_size = page.current_window.size
  end

  after do
    page.current_window.resize_to(*@original_window_size) if @original_window_size
  end

  context "when organization has mobile logo" do
    before do
      organization.mobile_logo.attach(
        io: File.open(Decidim::Dev.asset("city.jpeg")),
        filename: "mobile_logo.jpg",
        content_type: "image/jpeg"
      )
    end

    it "displays mobile logo in mobile view" do
      visit decidim.root_path

      page.current_window.resize_to(375, 667)

      within ".main-bar__logo-mobile" do
        expect(page).to have_css("img[src*='mobile_logo']")
        expect(page).to have_no_css("img[src*='favicon']")
      end
    end
  end

  context "when organization has no mobile logo but has favicon" do
    before do
      organization.favicon.attach(
        io: File.open(Decidim::Dev.asset("icon.png")),
        filename: "favicon.png",
        content_type: "image/png"
      )
    end

    it "falls back to favicon in mobile view" do
      visit decidim.root_path

      page.current_window.resize_to(375, 667)

      within ".main-bar__logo-mobile" do
        expect(page).to have_css("img[src*='favicon']")
        expect(page).to have_no_css("img[src*='mobile_logo']")
      end
    end
  end
end
