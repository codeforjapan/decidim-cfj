# frozen_string_literal: true

require "rails_helper"

# app/helpers/decidim/layout_helper.rb は本家の LayoutHelper を丸ごと置き換えているため、
# 本家 0.32.3 の修正（decidim/decidim#18149）をこちらにも入れている。
RSpec.describe Decidim::LayoutHelper do
  describe "#current_url" do
    before { helper.extend(Decidim::UrlHelper) }

    it "does not let request parameters change the scheme, host or path of the URL" do
      url = helper.current_url(
        "controller" => "decidim/pages",
        "action" => "index",
        "locale" => "ja",
        "foo" => "bar",
        "host" => "evil.example.org",
        "protocol" => "javascript",
        "script_name" => "javascript:alert(1)//"
      )

      expect(url).to include("foo=bar")
      expect(url).not_to include("evil.example.org")
      expect(url).not_to include("javascript")
    end
  end
end
