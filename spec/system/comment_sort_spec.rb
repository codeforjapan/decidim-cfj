# frozen_string_literal: true

require "rails_helper"

describe "Comments", :perform_enqueued do
  let!(:component) { create(:debates_component, organization:) }
  let!(:commentable) { create(:debate, :open_ama, component:) }

  let(:resource_path) { resource_locator(commentable).path }

  let!(:organization) { create(:organization) }
  let!(:user) { create(:user, :confirmed, organization:) }
  let!(:comments) { create_list(:comment, 3, commentable:) }

  around do |example|
    I18n.with_locale(:ja) { example.run }
  end

  before do
    switch_to_host(organization.host)

    comment = create(:comment, commentable:, body: "Most Rated Comment")
    create(:comment_vote, comment:, author: user, weight: 1)

    visit decidim.root_path(locale: :ja)

    Capybara.raise_server_errors = false
  end

  it "allows user to store selected comment order in cookies", :slow do
    # click_button "同意します"
    visit resource_path

    expect(page).to have_no_content("コメントは現時点で無効になっていますが")

    expect(page).to have_css(".comment", minimum: 1)

    # click "評価の高い順"
    within ".comments" do
      click_link "評価の高い順"
    end

    # show other page
    visit "/"

    # back to resource page
    visit resource_path

    expect(page).to have_css(".comment", minimum: 1)
    expect(page).to have_css("div.comment-order-by div a.underline", text: "評価の高い順")

    # click "新しい順"
    within ".comments" do
      click_link "新しい順"
    end

    # show other page
    visit "/"

    # back to resource page
    visit resource_path

    expect(page).to have_css(".comment", minimum: 1)
    expect(page).to have_css("div.comment-order-by div a.underline", text: "新しい順")
  end
end
