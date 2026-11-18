# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Footer" do
  include Devise::Test::IntegrationHelpers

  let(:organization) { create(:organization) }
  let(:user) { create(:user, :confirmed, organization:) }
  let(:footer) { Nokogiri::HTML(response.body).at_css(".main-footer") }

  before do
    host! organization.host
    sign_in user, scope: :user
    get "/#{organization.default_locale}/"
  end

  it "renders a heading for each column" do
    headings = footer.css("nav.footer__nav").map { |nav| nav.at_css("[data-controls] .h4")&.text.to_s.strip }

    expect(headings.size).to eq(4)
    expect(headings).to all(be_present)
  end
end
