# frozen_string_literal: true

require "rails_helper"

# CacheStore does not apply config.action_dispatch.cookies_same_site_protection
# to the session cookie, so the environment files set SameSite themselves.
describe "session store SameSite configuration" do
  it "sets SameSite=Lax on the session cookie in the environment files" do
    %w(production development).each do |env|
      line = Rails.root.join("config/environments/#{env}.rb").readlines
                  .find { |l| l.include?("config.session_store(") }

      expect(line).to include("same_site: :lax"), "#{env}.rb does not set same_site: :lax"
    end
  end
end
