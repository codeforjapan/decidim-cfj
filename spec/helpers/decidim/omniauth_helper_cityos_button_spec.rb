# frozen_string_literal: true

require "rails_helper"

RSpec.describe Decidim::OmniauthHelper do
  let(:organization) { instance_double(Decidim::Organization, enabled_omniauth_providers: providers) }

  before do
    without_partial_double_verification do
      allow(helper).to receive(:current_organization).and_return(organization)
    end
  end

  describe "#oauth_icon" do
    context "when CityOS has no icon configured" do
      let(:providers) { { cityos_dcp_login: { label: "CityOSでログイン" } } }

      it "renders the configured label only" do
        expect(helper.oauth_icon(:cityos_dcp_login)).to eq("<span>CityOSでログイン</span>")
      end
    end

    context "when CityOS has an icon configured" do
      let(:providers) { { cityos_dcp_login: { label: "CityOSでログイン", icon_path: "media/images/cityos.svg" } } }

      before do
        allow(helper).to receive(:external_icon).with("media/images/cityos.svg").and_return("<svg></svg>".html_safe)
      end

      it "renders the icon followed by the label" do
        expect(helper.oauth_icon(:cityos_dcp_login)).to eq("<svg></svg><span>CityOSでログイン</span>")
      end
    end

    context "when CityOS has no label configured" do
      let(:providers) { { cityos_dcp_login: {} } }

      it "falls back to the provider name" do
        expect(helper.oauth_icon(:cityos_dcp_login)).to eq("<span>Cityos dcp login</span>")
      end
    end

    context "with a provider other than CityOS" do
      let(:providers) { { facebook: { label: "Facebookでログイン", icon_path: "media/images/facebook.svg" } } }

      before do
        allow(helper).to receive(:external_icon).with("media/images/facebook.svg").and_return("<svg></svg>".html_safe)
      end

      it "keeps Decidim's behaviour and ignores the label" do
        expect(helper.oauth_icon(:facebook)).to eq("<svg></svg>")
      end
    end
  end
end
